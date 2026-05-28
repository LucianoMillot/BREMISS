process DKI_FITTING {
    tag "${sub_id}"
    label 'cpu_high'
    publishDir "${params.out_dir}/${sub_id}/metrics", mode: 'copy'

    input:
    tuple val(sub_id), path(dwi), path(bval), path(bvec), path(mask)

    output:
    tuple val(sub_id), path("${sub_id}_*.nii.gz"), emit: maps

    tuple val(sub_id), path("${sub_id}_Dxx.nii.gz"), path("${sub_id}_Dyy.nii.gz"), path("${sub_id}_Dzz.nii.gz"), path("${sub_id}_Dxy.nii.gz"), path("${sub_id}_Dxz.nii.gz"), path("${sub_id}_Dyz.nii.gz"), emit: for_alps

    tuple val(sub_id), path("${sub_id}_*.trk"), emit: streamlines

    script:
    """
    python3 ${baseDir}/scripts/dki.py \
        --input ${dwi} \
        --bval ${bval} \
        --bvec ${bvec} \
        --mask ${mask} \
        --prefix ${sub_id}
    """
}

process CALCULATE_ALPS_INDEX {
    tag "${sub_id}"
    publishDir "${params.out_dir}/${sub_id}/metrics", mode: 'copy'

    input:
    tuple val(sub_id), path(b0_corr_brain), path(mni_to_diff_mat), path(dxx), path(dyy), path(dzz), path(dxy), path(dxz), path(dyz)
    path create_spheres_script
    path compute_alps_script

    output:
    tuple val(sub_id), path("${sub_id}_ALPS_index.csv"), emit: alps_csv
    tuple val(sub_id), path("${sub_id}_ROI_*_in_Diffusion.nii.gz"), emit: rois

    script:
    """
    # 1. Generation of MNI spheres
    MNI_TEMPLATE="\$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz"
    python3 ${create_spheres_script} \$MNI_TEMPLATE

    # 2. Projection to Diffusion space
    for roi in PROJ_R ASSOC_R PROJ_L ASSOC_L; do
        flirt -in ROI_\${roi}_MNI.nii.gz \\
              -ref ${b0_corr_brain} \\
              -applyxfm -init ${mni_to_diff_mat} \\
              -out ${sub_id}_ROI_\${roi}_in_Diffusion.nii.gz \\
              -interp nearestneighbour
    done

    # 3. ALPS Index Calculation with Python Script
    python3 ${compute_alps_script} \\
        --sub_id ${sub_id} \\
        --dxx ${dxx} --dyy ${dyy} --dzz ${dzz} \\
        --dxy ${dxy} --dxz ${dxz} --dyz ${dyz} \\
        --affine ${mni_to_diff_mat} \\
        --roi_proj_l ${sub_id}_ROI_PROJ_L_in_Diffusion.nii.gz \\
        --roi_proj_r ${sub_id}_ROI_PROJ_R_in_Diffusion.nii.gz \\
        --roi_assoc_l ${sub_id}_ROI_ASSOC_L_in_Diffusion.nii.gz \\
        --roi_assoc_r ${sub_id}_ROI_ASSOC_R_in_Diffusion.nii.gz
    """
}
