import os
import sys
import numpy as np
import nibabel as nib

def print_usage():
    print("Usage: python manual_alps.py <sub_id> <ROI_NAME> <x> <y> <z>")
    print("Example: python manual_alps.py sub-Mingam PROJ_R 62 88 47")
    print("Valid ROI_NAMEs: PROJ_L, PROJ_R, ASSOC_L, ASSOC_R")
    sys.exit(1)

if len(sys.argv) != 6:
    print_usage()

sub_id = sys.argv[1]
roi_name = sys.argv[2]

try:
    vx, vy, vz = int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
except ValueError:
    print("Error: x, y, z coordinates must be integers (voxel coordinates).")
    print_usage()

valid_rois = ["PROJ_L", "PROJ_R", "ASSOC_L", "ASSOC_R"]
if roi_name not in valid_rois:
    print(f"Error: ROI_NAME must be one of {valid_rois}")
    print_usage()

# Project paths
# We assume this script is run from the `code` directory
metrics_dir = f"../derivatives/{sub_id}/metrics"

if not os.path.exists(metrics_dir):
    print(f"Error: Directory {metrics_dir} does not exist. Did the pipeline finish for this patient?")
    sys.exit(1)

# 1. Load reference image (e.g. Dxx) to get dimensions and affine
dxx_path = f"{metrics_dir}/{sub_id}_Dxx.nii.gz"
if not os.path.exists(dxx_path):
    print(f"Error: {dxx_path} missing.")
    sys.exit(1)

ref_img = nib.load(dxx_path)
data_shape = ref_img.shape
affine = ref_img.affine
zooms = ref_img.header.get_zooms()

print(f"[{sub_id}] Generating new {roi_name} ROI at voxel ({vx}, {vy}, {vz})...")

# 2. Generate new spherical mask at the specified voxel
radius_mm = 2.2
x, y, z = np.ogrid[0:data_shape[0], 0:data_shape[1], 0:data_shape[2]]

# Physical distance squared from the voxel center
dist_sq = ((x - vx)*zooms[0])**2 + ((y - vy)*zooms[1])**2 + ((z - vz)*zooms[2])**2

mask = np.zeros(data_shape, dtype=np.uint8)
mask[dist_sq <= radius_mm**2] = 1

out_img = nib.Nifti1Image(mask, affine, ref_img.header)
roi_path = f"{metrics_dir}/{sub_id}_ROI_{roi_name}_in_Diffusion.nii.gz"

# Overwrite the old ROI
nib.save(out_img, roi_path)
print(f"Saved new ROI: {roi_path}")

# 3. Recalculate ALPS index
print("Recalculating ALPS index...")

dyy_path = f"{metrics_dir}/{sub_id}_Dyy.nii.gz"
dzz_path = f"{metrics_dir}/{sub_id}_Dzz.nii.gz"

dxx_data = ref_img.get_fdata()
dyy_data = nib.load(dyy_path).get_fdata()
dzz_data = nib.load(dzz_path).get_fdata()

def get_mean(data, roi):
    roi_file = f"{metrics_dir}/{sub_id}_ROI_{roi}_in_Diffusion.nii.gz"
    if not os.path.exists(roi_file):
        print(f"Warning: {roi_file} not found. Cannot calculate ALPS.")
        return 0.0
    roi_mask = nib.load(roi_file).get_fdata() > 0
    if not np.any(roi_mask):
        print(f"Warning: ROI {roi} is empty!")
        return 0.0
    return np.mean(data[roi_mask])

dx_proj_l = get_mean(dxx_data, "PROJ_L")
dx_assoc_l = get_mean(dxx_data, "ASSOC_L")
dy_proj_l = get_mean(dyy_data, "PROJ_L")
dz_assoc_l = get_mean(dzz_data, "ASSOC_L")

dx_proj_r = get_mean(dxx_data, "PROJ_R")
dx_assoc_r = get_mean(dxx_data, "ASSOC_R")
dy_proj_r = get_mean(dyy_data, "PROJ_R")
dz_assoc_r = get_mean(dzz_data, "ASSOC_R")

try:
    alps_l = (dx_proj_l + dx_assoc_l) / (dy_proj_l + dz_assoc_l)
except ZeroDivisionError:
    alps_l = 0.0

try:
    alps_r = (dx_proj_r + dx_assoc_r) / (dy_proj_r + dz_assoc_r)
except ZeroDivisionError:
    alps_r = 0.0

alps_mean = (alps_l + alps_r) / 2.0

csv_path = f"{metrics_dir}/{sub_id}_ALPS_index.csv"
with open(csv_path, 'w') as f:
    f.write("subject,ALPS_Left,ALPS_Right,ALPS_Mean\n")
    f.write(f"{sub_id},{alps_l:.6f},{alps_r:.6f},{alps_mean:.6f}\n")

print(f"Updated {csv_path} with new values:")
print(f"ALPS_Left:  {alps_l:.4f}")
print(f"ALPS_Right: {alps_r:.4f}")
print(f"ALPS_Mean:  {alps_mean:.4f}")
print("Done!")
