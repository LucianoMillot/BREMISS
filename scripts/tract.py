import os
import nibabel as nib
import numpy as np
from dipy.io.gradients import read_bvals_bvecs
from dipy.core.gradients import gradient_table
from dipy.reconst.csdeconv import auto_response_ssst, ConstrainedSphericalDeconvModel
from dipy.direction import DeterministicMaximumDirectionGetter
from dipy.io.stateful_tractogram import Space, StatefulTractogram
from dipy.io.streamline import save_tractogram
from dipy.tracking.local_tracking import LocalTracking
from dipy.tracking.streamline import Streamlines
from dipy.tracking import utils
from dipy.tracking.stopping_criterion import ThresholdStoppingCriterion
from dipy.data import get_sphere

# Configuration des chemins
path = "./CARO_Dominique_19560124_Classic/preprocess/"
data_path = os.path.join(path, 'eddy_corrected_data.nii.gz')
# Correction du chemin bval (vérifie bien que le dossier 'raw' existe tel quel)
bval_path = './CARO_Dominique_19560124_Classic/raw/NIFTI/DTI-ALPS_301.bval'
bvec_path = os.path.join(path, 'eddy_corrected_data.eddy_rotated_bvecs')
mask_path = os.path.join(path, 'nodif_brain_mask_mask.nii.gz')

# 1. Chargement des données
print("Chargement des données...")
img = nib.load(data_path)
data = img.get_fdata()
affine = img.affine
mask = nib.load(mask_path).get_fdata() > 0
bvals, bvecs = read_bvals_bvecs(bval_path, bvec_path)
# Correction : passage de bvecs en argument nommé pour éviter le warning
gtab = gradient_table(bvals, bvecs=bvecs)

# 2. Estimation de la fonction de réponse
response, ratio = auto_response_ssst(gtab, data, roi_radii=10, fa_thr=0.7)

# 3. Fit du modèle CSD
print("Calcul des FOD (CSD)...")
csd_model = ConstrainedSphericalDeconvModel(gtab, response, sh_order_max=8)
csd_fit = csd_model.fit(data, mask=mask)

# 4. Paramétrage du Tracking
fa_img = nib.load(os.path.join(path, 'FA.nii.gz')).get_fdata()
seed_mask = (fa_img > 0.5) & mask
seeds = utils.seeds_from_mask(seed_mask, affine, density=2)

sphere = get_sphere('symmetric724')

dg = DeterministicMaximumDirectionGetter.from_shcoeff(csd_fit.shm_coeff, 
                                                      max_angle=30., 
                                                      sphere=sphere)

# 5. Lancement de la tractographie
print("Génération des fibres en cours (Streamlines)...")
stopping_criterion = ThresholdStoppingCriterion(fa_img, 0.2)
streamline_generator = LocalTracking(dg, stopping_criterion, seeds, affine, step_size=0.5)

# Matérialisation des fibres
streamlines = Streamlines(streamline_generator)

# 6. Sauvegarde au format .trk
sft = StatefulTractogram(streamlines, img, Space.RASMM)
save_tractogram(sft, os.path.join(path, 'tractography_csd.trk'))

print(f"Tractographie terminée ! Fichier sauvegardé : {os.path.join(path, 'tractography_csd.trk')}")