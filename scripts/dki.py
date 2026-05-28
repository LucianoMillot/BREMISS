import nibabel as nib
import numpy as np
import argparse
import os
from dipy.io.gradients import read_bvals_bvecs
from dipy.core.gradients import gradient_table
import dipy.reconst.dki as dki
from dipy.tracking.local_tracking import LocalTracking
from dipy.tracking.stopping_criterion import ThresholdStoppingCriterion
from dipy.tracking import utils
from dipy.tracking.streamline import Streamlines  
from dipy.direction import peaks_from_model
from dipy.io.stateful_tractogram import Space, StatefulTractogram
from dipy.io.streamline import save_tractogram
from dipy.data import get_sphere

def compute_dki(dwi_path, bval_path, bvec_path, mask_path, prefix):
    # 1. Chargement
    data_img = nib.load(dwi_path)
    data = data_img.get_fdata()
    affine = data_img.affine
    mask_img = nib.load(mask_path)
    mask = mask_img.get_fdata() > 0

    # 2. Gradients
    bvals, bvecs = read_bvals_bvecs(bval_path, bvec_path)
    gtab = gradient_table(bvals, bvecs=bvecs)

    # 3. Ajustement du modèle DKI
    print(f"Fitting DKI model for {prefix}...")
    dkimodel = dki.DiffusionKurtosisModel(gtab)
    dkifit = dkimodel.fit(data, mask=mask)

    # 4. Métriques scalaires
    fa = np.nan_to_num(dkifit.fa)
    metrics = {
        'MK': np.nan_to_num(dkifit.mk()),
        'FA': fa,
        'MD': np.nan_to_num(dkifit.md),
        'Dxx': np.nan_to_num(dkifit.quadratic_form[..., 0, 0]),
        'Dxy': np.nan_to_num(dkifit.quadratic_form[..., 0, 1]),
        'Dyy': np.nan_to_num(dkifit.quadratic_form[..., 1, 1]),
        'Dxz': np.nan_to_num(dkifit.quadratic_form[..., 0, 2]),
        'Dyz': np.nan_to_num(dkifit.quadratic_form[..., 1, 2]),
        'Dzz': np.nan_to_num(dkifit.quadratic_form[..., 2, 2])
    }

    # 5. Sauvegarde des métriques
    for name, data_array in metrics.items():
        out_name = f"{prefix}_{name}.nii.gz"
        img = nib.Nifti1Image(data_array.astype(np.float32), affine)
        nib.save(img, out_name)
        print(f"Saved: {out_name}")

    # 6. FA colorée (FA directionnelle)
    v1 = np.nan_to_num(dkifit.evecs[..., :, 0])
    color_fa = np.abs(v1) * fa[..., np.newaxis]
    color_img = nib.Nifti1Image(color_fa.astype(np.float32), affine)
    nib.save(color_img, f"{prefix}_color_fa.nii.gz")

    # 7. Tractographie
    print(f"Generating streamlines for {prefix}...")

    # Sphère de directions
    sphere = get_sphere('repulsion724')

    # Extraction des directions (pics)
    peaks = peaks_from_model(model=dkimodel, data=data, 
                             sphere=sphere, 
                             relative_peak_threshold=.5, 
                             min_separation_angle=25, 
                             mask=mask, 
                             parallel=True)

    # Critère d'arrêt et points de départ (graines)
    stopping_criterion = ThresholdStoppingCriterion(fa, .2)
    seeds = utils.seeds_from_mask(mask, density=1, affine=affine)

    # Suivi des fibres (Tractographie locale)
    streamlines_generator = LocalTracking(peaks, stopping_criterion, seeds, affine, step_size=.5)
    streamlines = Streamlines(streamlines_generator)

    # Sauvegarde des fibres (tractogramme)
    sft = StatefulTractogram(streamlines, data_img, Space.RASMM)
    save_tractogram(sft, f"{prefix}_tracto.trk")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Ajustement DKI avec DIPY et contrôle qualité de la tractographie')
    parser.add_argument('--input', required=True)
    parser.add_argument('--bval', required=True)
    parser.add_argument('--bvec', required=True)
    parser.add_argument('--mask', required=True)
    parser.add_argument('--prefix', required=True)
    args = parser.parse_args()
    compute_dki(args.input, args.bval, args.bvec, args.mask, args.prefix)