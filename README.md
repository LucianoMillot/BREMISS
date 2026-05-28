# BREMISS Pipeline: Multi-Shell Diffusion Neuroimaging & ALPS Index

This repository contains the source code for the diffusion MRI processing pipeline developed for the **BREMISS** protocol. It is specifically designed to automate the preprocessing of complex DWI data (post-stroke patients with lesions) and to robustly extract advanced micro-structural biomarkers: the Kurtosis tensor (DKI) and the ALPS index (with strict geometric correction).

## Key Features

1. **Signal Restoration**: MP-PCA denoising, Gibbs ringing correction, and Rician bias correction (`MRtrix3`).
2. **Geometric Correction (Deep Learning)**: Synthesis of a reversed b=0 volume via `Synb0-DISCO` (Apptainer) to compensate for the lack of RPE (Reverse Phase Encoding) acquisition.
3. **Motion Correction**: `topup` and `eddy_cuda` algorithms (FSL) with GPU acceleration.
4. **Kurtosis Modeling (DKI)**: Fitting the non-Gaussian tensor model using `DIPY` to extract complete metric maps ($D_{xx}, D_{yy}, D_{zz}, D_{xy}, D_{xz}, D_{yz}$), FA, MD, MK.
5. **ALPS Index Calculation with Recalibration**: Robust 12-DOF affine registration to MNI space, projection of the 4 ROIs (Corona Radiata, SLF) into native space, and **algebraic geometric recalibration** of the tensor to perfectly compensate for the patient's head tilt mathematically.

## System Requirements & Configuration

The pipeline infrastructure is designed for high-performance computing servers. The default configuration targets the following hardware architecture:
- **CPU**: 56 allocated cores
- **RAM**: 240 GB
- **GPU**: 2 NVIDIA GPUs (Currently running on 2x NVIDIA GeForce GTX 1080 Ti, Driver Version: 580.126.20, CUDA Version: 13.0) for Eddy acceleration.

### Software Dependencies

* **Operating System**: Linux (Ubuntu recommended) with NVIDIA drivers and CUDA toolkit.
* **Orchestrator**: [Nextflow](https://www.nextflow.io/) (version 22.0+)
* **Containerization**: [Apptainer](https://apptainer.org/) (formerly Singularity). Required to run the Synb0-DISCO Docker image.
* **FSL (Native Install)**: `FSL` (version 6.0.7.22) must be installed natively on the system (e.g., in `/usr/local/fsl` or `~/fsl`), as `eddy_cuda` requires native CUDA libraries that are not reliably packaged via Conda. Ensure `$FSLDIR` is correctly set in your environment.
* **Conda Environment (`bremiss`)**: 
  The execution of local processes requires a Conda environment. An `environment.yml` file is provided at the root of the repository. It includes:
  * `mrtrix3` (v3.0.8)
  * `ants` (v2.6.5)
  * Python 3.11.15 with `dipy` (v1.12.0), `nibabel` (v5.4.2), `numpy` (v2.4.4)
* **FreeSurfer License**: Required for the internal scripts of Synb0-DISCO (path to be defined in the configuration).

## Inputs Data Architecture

The raw cohort data must be structured according to the BIDS (Brain Imaging Data Structure) standard in a parent directory. The pipeline expects the following files for each subject:

- **Anatomical Data (`anat/`)**:
  - `sub-ID_T1.nii.gz`: 3D T1-weighted structural MRI used as the anatomical reference for the synthesis of the b=0 volume and MNI registration.
- **Diffusion Data (`dwi/`)**:
  - `sub-ID_dwi.nii.gz`: Multi-shell diffusion weighted sequence (e.g., $b \in \{0, 500, 2000, 3000\}\, \text{s/mm}^2$).
  - `sub-ID_dwi.bval` & `sub-ID_dwi.bvec`: Gradient tables containing the b-values and diffusion vectors.
  - `sub-ID_dwi.json`: BIDS metadata file, mandatory for extracting the `EstimatedTotalReadoutTime` parameter used by `topup` and `eddy`.

```text
../
└── inputs/
    └── sub-ID/
        ├── anat/
        │   └── sub-ID_T1.nii.gz
        └── dwi/
            ├── sub-ID_dwi.nii.gz
            ├── sub-ID_dwi.bval
            ├── sub-ID_dwi.bvec
            └── sub-ID_dwi.json
```

## Outputs (Derivatives) Architecture

The pipeline will automatically generate a `derivatives/` folder at the root level, containing the processed data and the final extracted metrics for each subject.

```text
../
└── derivatives/
    └── sub-ID/
        ├── preprocess/
        │   ├── sub-ID_eddy_corr.nii.gz         # Fully corrected DWI (motion, eddy, distortion, bias)
        │   ├── sub-ID_eddy_rotated.bvecs       # Adjusted gradient vectors
        │   └── sub-ID_mask.nii.gz              # Brain inclusion mask in diffusion space
        └── metrics/
            ├── sub-ID_Dxx.nii.gz               # DKI tensor component (along X)
            ├── sub-ID_Dyy.nii.gz               # DKI tensor component (along Y)
            ├── sub-ID_Dzz.nii.gz               # DKI tensor component (along Z)
            ├── sub-ID_Dxy.nii.gz, etc.         # Off-diagonal tensor components
            ├── sub-ID_Color_FA.nii.gz          # Directional Fractional Anisotropy map
            └── sub-ID_ALPS_index.csv           # Final ALPS metrics for the left and right hemispheres
```

## Running the Pipeline

1. **Activate the environment**:
   ```bash
   conda env create -f environment.yml  # First time setup
   conda activate bremiss
   ```

2. **Adjust the configuration**:
   Modify the `nextflow.config` file to specify the exact path to your FreeSurfer license (`fs_license`) and adjust the global resource budget (`executor { cpus = X; memory = 'Y GB' }`).

3. **Execute the global processing**:
   ```bash
   nextflow run main.nf -resume
   ```
   The `-resume` option allows you to resume computation from where it stopped in case of an interruption, using Nextflow's execution cache (`work/` directory).

## Manual Curation (ALPS Post-Processing)

If the automated affine registration fails or places an ROI inside a cystic lacune in a highly lesioned patient, you can manually reposition the center of the sphere (using coordinates obtained in the FSLeyes interface) and recalculate the CSV file instantly without restarting the pipeline:
```bash
conda run -n bremiss python3 scripts/manual_alps.py <sub_id> <ROI_NAME> <X> <Y> <Z>
```
