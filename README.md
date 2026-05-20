# BREMISS Nextflow Pipeline : Multi-Shell Diffusion & ALPS Index

Ce dépôt contient le pipeline de neuroimagerie de diffusion multi-shell développé pour le projet **BREMISS**. Il est conçu pour le prétraitement automatisé de données DWI complexes (patients post-AVC) et l'extraction de métriques micro-structurelles avancées (Kurtosis - DKI, Indice ALPS).

## 🚀 Fonctionnalités

Le pipeline traite les images IRM de diffusion de bout en bout :
1. **Nettoyage (Cleaning)** : Débruitage (MP-PCA), correction des artefacts de Gibbs, et correction de biais Ricien via MRtrix3.
2. **Correction Géométrique & Mouvement** : Synthèse de b0 inversé via Deep Learning (`Synb0-DISCO`), correction des distorsions de susceptibilité (TOPUP) et des courants de Foucault (Eddy CUDA multi-GPU). Correction de biais B1 (N4).
3. **Modélisation Tensorielle (DKI)** : Ajustement du modèle Diffusion Kurtosis Imaging (DIPY) pour extraire FA, MD, MK et $D_{xx}, D_{yy}, D_{zz}$.
4. **Calcul de l'Indice ALPS** : Recalage robuste (12-DOF Affine) vers l'espace MNI, projection des régions d'intérêt sphériques (Corona Radiata, SLF) et calcul automatisé de l'indice ALPS par patient.

## 📁 Architecture du Code

L'orchestration est gérée par **Nextflow DSL2** :
- `main.nf` : Le point d'entrée principal qui définit le dataflow (le graphe d'exécution).
- `nextflow.config` : Configuration des profils matériels (CPUs/GPUs), des environnements et de l'orchestrateur.
- `modules/` :
  - `preprocessing.nf` / `cleaning.nf` : Tâches de préparation du signal.
  - `registration.nf` : Alignements croisés (T1 ↔ Diffusion ↔ MNI) et exécution de `Synb0-DISCO`.
  - `correct_motion.nf` : Corrections temporelles et géométriques (Eddy).
  - `metrics.nf` : Estimation DKI et scripts de calcul de l'Indice ALPS.
- `scripts/` : Wrappers bash (ex: gestionnaire multi-GPU pour Eddy) et scripts Python auxiliaires.

## 🛠️ Pré-requis

- **Environnement Système** : Linux (Ubuntu recommandé).
- **Gestionnaire de flux** : [Nextflow](https://www.nextflow.io/) (version 22.0+).
- **Conteneurisation** : [Apptainer/Singularity](https://apptainer.org/) (nécessaire pour Synb0-DISCO).
- **Conda** : Environnement contenant `FSL`, `MRtrix3`, `ANTs`, `DIPY`, et `nibabel`.
- **Licence FreeSurfer** : Nécessaire pour le pipeline.

## ⚙️ Configuration & Lancement

1. **Environnement virtuel** :
Assurez-vous que l'environnement Conda `bremiss` est disponible.

2. **Structure des données** :
Le pipeline s'attend à trouver les données au format BIDS ou structurées ainsi dans le dossier parent :
```text
../inputs/
└── sub-PatientID/
    ├── anat/
    │   └── sub-PatientID_T1.nii.gz
    └── dwi/
        ├── sub-PatientID_dwi.nii.gz
        ├── sub-PatientID_dwi.bval
        ├── sub-PatientID_dwi.bvec
        └── sub-PatientID_dwi.json
```

3. **Lancement du pipeline** :
```bash
# Pour simuler le lancement (dry-run)
nextflow run main.nf -preview

# Lancement normal (le paramètre fs_license est modifiable)
nextflow run main.nf -resume --fs_license /chemin/vers/license.txt
```

## 📊 Résultats
Les résultats finaux (dérivés) sont générés dans `../derivatives/` par sujet.
Le pipeline produit également un fichier CSV synthétique contenant l'Indice ALPS calculé par hémisphère pour chaque patient.
