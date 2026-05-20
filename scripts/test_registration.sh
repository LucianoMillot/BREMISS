#!/bin/bash

# Sécurité : arrête le script si une commande échoue
set -e

echo "=== Début du recalage T1 -> Espace Diffusion (pour ALPS) ==="

# --- VARIABLES D'ENTRÉE ---
# Pour le post-processing, il est CRUCIAL de prendre le b0 CORRIGÉ des distorsions
# (par exemple le b0 extrait après EDDY, ou le b0_vrt généré par SynthB0)
T1_IN="../../derivatives/sub-Guillou/anat/sub-Guillou_T1_resampled.nii.gz"
B0_CORRIGE_IN="../../derivatives/sub-Guillou/preprocess/sub-Guillou_b0_vrt.nii.gz" # ou l'image FA si vous préférez FLIRT classique

echo "[1/3] Standardisation (fslreorient2std) et Crop (robustfov)..."
fslreorient2std ${T1_IN} T1_std.nii.gz
fslreorient2std ${B0_CORRIGE_IN} b0_corr_std.nii.gz
robustfov -i T1_std.nii.gz -r T1_cropped.nii.gz

echo "[2/3] Extraction cérébrale (BET)..."
bet T1_cropped.nii.gz T1_brain.nii.gz -R -f 0.3
bet b0_corr_std.nii.gz b0_corr_brain.nii.gz -f 0.3

echo "[3/4] Recalage BBR (epi_reg) : b0 corrigé -> T1..."
# epi_reg calcule toujours la transformation de l'EPI vers le T1
epi_reg --epi=b0_corr_std.nii.gz \
        --t1=T1_cropped.nii.gz \
        --t1brain=T1_brain.nii.gz \
        --out=b0_to_T1_epireg

echo "[4/4] Inversion de la matrice (T1 -> b0) et application..."
# On inverse la matrice pour obtenir T1 -> Diffusion
convert_xfm -omat T1_to_Diffusion.mat -inverse b0_to_T1_epireg.mat

# On applique la matrice au T1 ENTIER (avec crâne) pour voir ce qui est rogné par la boîte du b0
flirt -in T1_cropped.nii.gz \
      -ref b0_corr_brain.nii.gz \
      -applyxfm -init T1_to_Diffusion.mat \
      -out T1_in_Diffusion_space.nii.gz

echo "=== Terminé avec succès ! ==="
echo "La matrice de transformation est : T1_to_Diffusion.mat"
echo "Pour vérifier l'alignement, lancez :"
echo "fsleyes b0_corr_brain.nii.gz T1_in_Diffusion_space.nii.gz"