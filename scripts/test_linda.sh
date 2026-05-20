#!/bin/bash
set -e

echo "=== Début du test de segmentation LINDA ==="

# --- VARIABLES ---
# On utilise le T1 original ou rééchantillonné
T1_IN="../../derivatives/sub-Guillou/anat/sub-Guillou_T1_resampled.nii.gz"
OUTPUT_DIR="LINDA_OUTPUT"

mkdir -p $OUTPUT_DIR
# On copie le T1 dans le dossier de sortie pour que LINDA génère ses fichiers ici
cp $T1_IN $OUTPUT_DIR/T1_for_linda.nii.gz

T1_LINDA="$OUTPUT_DIR/T1_for_linda.nii.gz"

echo "[1/3] Téléchargement et Exécution de LINDA via Apptainer..."
# Apptainer va télécharger l'image docker (ça peut prendre quelques minutes la première fois)
# et exécuter la commande Rscript à l'intérieur.
apptainer run docker://dorianps/linda:latest Rscript -e "library(LINDA); linda_predict('${T1_LINDA}')"

echo "[2/3] Récupération du masque de la lésion..."
# LINDA crée un dossier du même nom que le fichier T1 (sans l'extension)
# Le fichier du masque de la lésion s'appelle généralement Prediction3_...
LESION_MASK=$(find ${OUTPUT_DIR}/T1_for_linda -name "Prediction3_*.nii.gz" | head -n 1)

if [ -z "$LESION_MASK" ]; then
    echo "Erreur : LINDA n'a pas généré le masque."
    exit 1
fi

echo "Masque trouvé : $LESION_MASK"
cp $LESION_MASK sub-Guillou_lesion_linda.nii.gz

echo "[3/3] Inversion du masque pour FSL (Cost-Function Masking)..."
# FSL a besoin de 1=sain, 0=lésion.
# LINDA donne 1=lésion, 0=sain. On inverse.
fslmaths sub-Guillou_lesion_linda.nii.gz -mul -1 -add 1 -bin sub-Guillou_lesion_inverted_for_fsl.nii.gz

echo "=== Terminé ! ==="
echo "Vous pouvez vérifier la segmentation LINDA avec :"
echo "fsleyes $T1_IN -cm greyscale sub-Guillou_lesion_linda.nii.gz -cm red"
