import nibabel as nib
import numpy as np
import sys
import os

mni_template = sys.argv[1]
radius_mm = 2.5

img = nib.load(mni_template)
data_shape = img.shape
affine = img.affine
inv_affine = np.linalg.inv(affine)

# MNI Coordinates (X, Y, Z)
rois = {
    "PROJ_R": [26, -18, 28],
    "ASSOC_R": [38, -18, 28],
    "PROJ_L": [-26, -18, 28],
    "ASSOC_L": [-38, -18, 28]
}

x, y, z = np.ogrid[0:data_shape[0], 0:data_shape[1], 0:data_shape[2]]

for name, coords in rois.items():
    center_vox = nib.affines.apply_affine(inv_affine, coords)
    
    # Distance in mm. For isotropic 1mm, vox dist == mm dist.
    # MNI152_1mm is isotropic.
    dist_sq = (x - center_vox[0])**2 + (y - center_vox[1])**2 + (z - center_vox[2])**2
    
    mask = np.zeros(data_shape, dtype=np.uint8)
    mask[dist_sq <= radius_mm**2] = 1
    
    out_img = nib.Nifti1Image(mask, affine, img.header)
    nib.save(out_img, f"ROI_{name}_MNI.nii.gz")
    print(f"Created ROI_{name}_MNI.nii.gz")
