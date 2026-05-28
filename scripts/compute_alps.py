import nibabel as nib
import numpy as np
import argparse
import os
import sys

def compute_diff_along_vector(D, u):
    """
    D is (X,Y,Z, 3, 3) symmetric tensor
    u is (3,) unit vector
    Computes u^T D u for each voxel.
    """
    res = np.zeros(D.shape[:-2])
    for i in range(3):
        for j in range(3):
            res += D[..., i, j] * u[i] * u[j]
    return res

def get_mean(data_vol, roi_path):
    if not os.path.exists(roi_path):
        print(f"Warning: {roi_path} not found. Cannot calculate ALPS.")
        return 0.0
    roi_mask = nib.load(roi_path).get_fdata() > 0
    if not np.any(roi_mask):
        print(f"Warning: ROI {roi_path} is empty!")
        return 0.0
    return np.mean(data_vol[roi_mask])

def main():
    parser = argparse.ArgumentParser(description='Compute ALPS Index with Anatomical Rotation')
    parser.add_argument('--sub_id', required=True)
    parser.add_argument('--dxx', required=True)
    parser.add_argument('--dyy', required=True)
    parser.add_argument('--dzz', required=True)
    parser.add_argument('--dxy', required=True)
    parser.add_argument('--dxz', required=True)
    parser.add_argument('--dyz', required=True)
    parser.add_argument('--affine', required=True, help="MNI to Diffusion affine matrix")
    
    # ROIs
    parser.add_argument('--roi_proj_l', required=True)
    parser.add_argument('--roi_proj_r', required=True)
    parser.add_argument('--roi_assoc_l', required=True)
    parser.add_argument('--roi_assoc_r', required=True)

    args = parser.parse_args()

    # Load tensor components
    Dxx = nib.load(args.dxx).get_fdata()
    Dyy = nib.load(args.dyy).get_fdata()
    Dzz = nib.load(args.dzz).get_fdata()
    Dxy = nib.load(args.dxy).get_fdata()
    Dxz = nib.load(args.dxz).get_fdata()
    Dyz = nib.load(args.dyz).get_fdata()

    # Reconstruct 3x3 symmetric tensor
    shape = Dxx.shape
    D = np.zeros(shape + (3, 3))
    D[..., 0, 0] = Dxx
    D[..., 1, 1] = Dyy
    D[..., 2, 2] = Dzz
    
    D[..., 0, 1] = Dxy
    D[..., 1, 0] = Dxy
    
    D[..., 0, 2] = Dxz
    D[..., 2, 0] = Dxz
    
    D[..., 1, 2] = Dyz
    D[..., 2, 1] = Dyz

    # Load Affine and extract rotation/scaling
    affine_mat = np.loadtxt(args.affine)
    A = affine_mat[0:3, 0:3]

    # In FSL, MNI X is Right-to-Left (positive X is Left). Y is P-A. Z is I-S.
    # The columns of A represent the transformation of MNI unit vectors to Diffusion space.
    u_x_unnorm = A[:, 0]
    u_y_unnorm = A[:, 1]
    u_z_unnorm = A[:, 2]

    u_x = u_x_unnorm / np.linalg.norm(u_x_unnorm)
    u_y = u_y_unnorm / np.linalg.norm(u_y_unnorm)
    u_z = u_z_unnorm / np.linalg.norm(u_z_unnorm)

    # Compute anatomical Dxx, Dyy, Dzz
    Dxx_anat = compute_diff_along_vector(D, u_x)
    Dyy_anat = compute_diff_along_vector(D, u_y)
    Dzz_anat = compute_diff_along_vector(D, u_z)

    # Calculate means in ROIs
    dx_proj_l = get_mean(Dxx_anat, args.roi_proj_l)
    dx_assoc_l = get_mean(Dxx_anat, args.roi_assoc_l)
    dy_proj_l = get_mean(Dyy_anat, args.roi_proj_l)
    dz_assoc_l = get_mean(Dzz_anat, args.roi_assoc_l)

    dx_proj_r = get_mean(Dxx_anat, args.roi_proj_r)
    dx_assoc_r = get_mean(Dxx_anat, args.roi_assoc_r)
    dy_proj_r = get_mean(Dyy_anat, args.roi_proj_r)
    dz_assoc_r = get_mean(Dzz_anat, args.roi_assoc_r)

    # Calculate ALPS
    try:
        alps_l = (dx_proj_l + dx_assoc_l) / (dy_proj_l + dz_assoc_l)
    except ZeroDivisionError:
        alps_l = 0.0

    try:
        alps_r = (dx_proj_r + dx_assoc_r) / (dy_proj_r + dz_assoc_r)
    except ZeroDivisionError:
        alps_r = 0.0

    alps_mean = (alps_l + alps_r) / 2.0

    # Write to CSV
    csv_path = f"{args.sub_id}_ALPS_index.csv"
    with open(csv_path, 'w') as f:
        f.write("subject,ALPS_Left,ALPS_Right,ALPS_Mean\n")
        f.write(f"{args.sub_id},{alps_l:.6f},{alps_r:.6f},{alps_mean:.6f}\n")
    
    print(f"[{args.sub_id}] ALPS Left: {alps_l:.4f} | Right: {alps_r:.4f} | Mean: {alps_mean:.4f}")

if __name__ == "__main__":
    main()
