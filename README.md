# BREMISS Nextflow Pipeline: Multi-Shell Diffusion & ALPS Index

This repository contains the multi-shell diffusion neuroimaging pipeline developed for the **BREMISS** project. It is designed for the automated preprocessing of complex DWI data (post-stroke patients) and the extraction of advanced micro-structural metrics (Kurtosis - DKI, ALPS Index).

## 🚀 Features

The pipeline processes diffusion MRI images end-to-end:
1. **Cleaning**: Denoising (MP-PCA), Gibbs ringing correction, and Rician bias correction using MRtrix3.
2. **Geometric & Motion Correction**: Synthesis of reversed b0 via Deep Learning (`Synb0-DISCO`), susceptibility distortion correction (TOPUP), and eddy currents correction (Eddy CUDA multi-GPU). B1 bias field correction (N4).
3. **Tensor Modeling (DKI)**: Fitting the Diffusion Kurtosis Imaging model (DIPY) to extract FA, MD, MK and $D_{xx}, D_{yy}, D_{zz}$.
4. **ALPS Index Calculation**: Robust registration (12-DOF Affine) to MNI space, projection of spherical regions of interest (Corona Radiata, SLF) and automated calculation of the ALPS index per patient.

## 📁 Code Architecture

The orchestration is managed by **Nextflow DSL2**:
- `main.nf`: The main entry point defining the dataflow (execution graph).
- `nextflow.config`: Configuration of hardware profiles (CPUs/GPUs), environments, and the orchestrator.
- `modules/`:
  - `preprocessing.nf` / `cleaning.nf`: Signal preparation tasks.
  - `registration.nf`: Cross-alignments (T1 ↔ Diffusion ↔ MNI) and execution of `Synb0-DISCO`.
  - `correct_motion.nf`: Temporal and geometric corrections (Eddy).
  - `metrics.nf`: DKI estimation and ALPS Index calculation scripts.
- `scripts/`: Bash wrappers (e.g., multi-GPU manager for Eddy) and auxiliary Python scripts.

## 🛠️ Prerequisites

- **OS**: Linux (Ubuntu recommended).
- **Workflow Manager**: [Nextflow](https://www.nextflow.io/) (version 22.0+).
- **Containerization**: [Apptainer/Singularity](https://apptainer.org/) (required for Synb0-DISCO).
- **Conda**: Environment containing `FSL`, `MRtrix3`, `ANTs`, `DIPY`, and `nibabel`.
- **FreeSurfer License**: Required for the pipeline.

## ⚙️ Configuration & Execution

1. **Virtual Environment**:
Ensure the `bremiss` Conda environment is available.

2. **Data Structure**:
The pipeline expects to find the data in BIDS format or structured as follows in the parent folder:
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

3. **Running the Pipeline**:
```bash
# To simulate the execution (dry-run)
nextflow run main.nf -preview

# Normal execution (the fs_license parameter can be modified)
nextflow run main.nf -resume --fs_license /path/to/license.txt
```

## 📊 Results
The final results (derivatives) are generated in `../derivatives/` per subject.
The pipeline also produces a synthetic CSV file containing the calculated ALPS Index per hemisphere for each patient.
