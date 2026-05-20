#!/bin/bash
set -e

echo "=== Début du traitement ALPS (Sphères MNI -> Diffusion) ==="

# --- VARIABLES D'ENTRÉE ---
T1_IN="../../derivatives/sub-Guillou/anat/sub-Guillou_T1_resampled.nii.gz"
T1_BRAIN="T1_brain.nii.gz"
B0_REF="../../derivatives/sub-Guillou/preprocess/sub-Guillou_b0_vrt.nii.gz"
T1_TO_DIFF_MAT="T1_to_Diffusion.mat"
MNI_TEMPLATE="$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz"

# --- PARAMÈTRES ALPS ---
# Coordonnées MNI approximatives :
# SCR (Projection) : X=±26, Y=-18, Z=28
# SLF (Association) : X=±38, Y=-18, Z=28
RADIUS=2.5 # Rayon de 2.5mm -> Sphère de 5mm

# Génération instantanée des sphères via Python (nibabel)
$FSLDIR/bin/fslpython create_spheres.py $MNI_TEMPLATE

echo "[2/4] Calcul du recalage AFFINE T1 -> MNI..."
flirt -in $T1_BRAIN -ref $MNI_TEMPLATE -omat T1_to_MNI_affine.mat

echo "[3/4] Inversion et combinaison des matrices..."
# 1. On inverse pour avoir MNI -> T1
convert_xfm -omat MNI_to_T1_affine.mat -inverse T1_to_MNI_affine.mat

# 2. On combine (MNI -> T1) et (T1 -> Diffusion) en une seule matrice (MNI -> Diffusion)
convert_xfm -omat MNI_to_Diffusion_affine.mat -concat $T1_TO_DIFF_MAT MNI_to_T1_affine.mat

echo "[4/4] Projection vers l'espace Diffusion (Affine uniquement)..."
for roi in PROJ_R ASSOC_R PROJ_L ASSOC_L; do
    echo " -> Déformation de $roi"
    flirt -in ROI_${roi}_MNI.nii.gz \
          -ref $B0_REF \
          -applyxfm -init MNI_to_Diffusion_affine.mat \
          -out ROI_${roi}_in_Diffusion.nii.gz \
          -interp nearestneighbour
done

echo "=== Terminé ! ==="
echo "Pour vérifier l'alignement sur le b0 :"
echo "fsleyes b0_corr_brain.nii.gz -cm greyscale ROI_PROJ_R_in_Diffusion.nii.gz -cm red ROI_ASSOC_R_in_Diffusion.nii.gz -cm blue ROI_PROJ_L_in_Diffusion.nii.gz -cm red ROI_ASSOC_L_in_Diffusion.nii.gz -cm blue"