process EXTRACT_B0 {
    tag "${sub_id}"
    cpus 4

    input:
    tuple val(sub_id), path(clean_dwi), path(bval), path(bvec)

    output:
    tuple val(sub_id), path("${sub_id}_mean_b0.nii.gz")

    script:
    """
    dwiextract ${clean_dwi} -fslgrad ${bvec} ${bval} -bzero - | mrmath - mean ${sub_id}_mean_b0.nii.gz -axis 3
    """
}

process SYNTHB0 {
    tag "${sub_id}"
    publishDir "${params.out_dir}/${sub_id}/preprocess", mode: 'copy'

    input:
    tuple val(sub_id), path(t1), path(b0_mean), val(readout_time)

    output:
    // Output 1: Corrected image for the mask
    tuple val(sub_id), path("${sub_id}_b0_vrt.nii.gz"), emit: b0_vrt
    // Output 2: Topup files for Eddy
    tuple val(sub_id), path("topup_results*"), emit: topup_files
    // Output 3: Acqparams file
    tuple val(sub_id), path("acqparams_eddy.txt"), emit: acqparams_eddy

    script:
    """
    mkdir -p INPUTS OUTPUTS
    cp -L ${t1} INPUTS/T1.nii.gz
    cp -L ${b0_mean} INPUTS/b0.nii.gz

    echo "0 1 0 ${readout_time}" > INPUTS/acqparams.txt
    echo "0 -1 0 0" >> INPUTS/acqparams.txt

    echo "0 1 0 ${readout_time}" > acqparams_eddy.txt
    echo "0 -1 0 0.01" >> acqparams_eddy.txt

    cp INPUTS/acqparams.txt ./acqparams.txt

    bash /extra/pipeline.sh /INPUTS /OUTPUTS

    mv OUTPUTS/b0_u.nii.gz ${sub_id}_b0_vrt.nii.gz
    mv OUTPUTS/topup_fieldcoef.nii.gz topup_results_fieldcoef.nii.gz
    mv OUTPUTS/topup_movpar.txt topup_results_movpar.txt
    """
}

process REGISTER_T1_TO_B0 {
    tag "${sub_id}"
    publishDir "${params.out_dir}/${sub_id}/preprocess", mode: 'copy'

    input:
    tuple val(sub_id), path(t1_resampled), path(b0_corr)

    output:
    tuple val(sub_id), path("${sub_id}_T1_to_Diffusion.mat"), emit: mat
    tuple val(sub_id), path("${sub_id}_T1_in_Diffusion_space.nii.gz"), emit: t1_diff
    tuple val(sub_id), path("${sub_id}_T1_brain.nii.gz"), emit: t1_brain
    tuple val(sub_id), path("${sub_id}_b0_corr_brain.nii.gz"), emit: b0_brain

    script:
    """
    echo "=== Starting T1 -> Diffusion Space Registration ==="
    
    # 1. Standardization and Crop
    fslreorient2std ${t1_resampled} T1_std.nii.gz
    fslreorient2std ${b0_corr} b0_corr_std.nii.gz
    robustfov -i T1_std.nii.gz -r T1_cropped.nii.gz
    
    # 2. BET
    bet T1_cropped.nii.gz ${sub_id}_T1_brain.nii.gz -R -f 0.3
    bet b0_corr_std.nii.gz ${sub_id}_b0_corr_brain.nii.gz -f 0.3
    
    # 3. BBR Registration (b0 -> T1)
    epi_reg --epi=b0_corr_std.nii.gz \\
            --t1=T1_cropped.nii.gz \\
            --t1brain=${sub_id}_T1_brain.nii.gz \\
            --out=b0_to_T1_epireg
            
    # 4. Inversion (T1 -> b0)
    convert_xfm -omat ${sub_id}_T1_to_Diffusion.mat -inverse b0_to_T1_epireg.mat
    
    # 5. Application for Visual QA
    flirt -in T1_cropped.nii.gz \\
          -ref ${sub_id}_b0_corr_brain.nii.gz \\
          -applyxfm -init ${sub_id}_T1_to_Diffusion.mat \\
          -out ${sub_id}_T1_in_Diffusion_space.nii.gz
    """
}

process REGISTER_MNI_TO_T1 {
    tag "${sub_id}"

    input:
    tuple val(sub_id), path(t1_brain), path(t1_to_diff_mat)

    output:
    tuple val(sub_id), path("${sub_id}_MNI_to_Diffusion_affine.mat"), emit: mni_to_diff_mat

    script:
    """
    # T1 -> MNI Registration (Affine) for ALPS
    MNI_TEMPLATE="\$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz"
    flirt -in ${t1_brain} -ref \$MNI_TEMPLATE -omat T1_to_MNI_affine.mat
    
    # Combination for MNI -> Diffusion (MNI -> T1 -> Diff)
    convert_xfm -omat MNI_to_T1_affine.mat -inverse T1_to_MNI_affine.mat
    convert_xfm -omat ${sub_id}_MNI_to_Diffusion_affine.mat -concat ${t1_to_diff_mat} MNI_to_T1_affine.mat
    """
}
