process DKI_FITTING {
    tag "${sub_id}"
    label 'cpu_high'
    publishDir "${params.out_dir}/${sub_id}/metrics", mode: 'copy'

    input:
    tuple val(sub_id), path(dwi), path(bval), path(bvec), path(mask)

    output:
    tuple val(sub_id), path("${sub_id}_*.nii.gz"), emit: maps

    tuple val(sub_id), path("${sub_id}_Dxx.nii.gz"), path("${sub_id}_Dyy.nii.gz"), path("${sub_id}_Dzz.nii.gz"), emit: for_alps

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
    tuple val(sub_id), path(b0_corr_brain), path(mni_to_diff_mat), path(dxx), path(dyy), path(dzz)

    output:
    tuple val(sub_id), path("${sub_id}_ALPS_index.csv"), emit: alps_csv
    tuple val(sub_id), path("${sub_id}_ROI_*_in_Diffusion.nii.gz"), emit: rois

    script:
    """
    # 1. Génération des sphères MNI
    MNI_TEMPLATE="\$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz"
    python3 ${baseDir}/scripts/create_spheres.py \$MNI_TEMPLATE

    # 2. Projection vers l'espace Diffusion
    for roi in PROJ_R ASSOC_R PROJ_L ASSOC_L; do
        flirt -in ROI_\${roi}_MNI.nii.gz \\
              -ref ${b0_corr_brain} \\
              -applyxfm -init ${mni_to_diff_mat} \\
              -out ${sub_id}_ROI_\${roi}_in_Diffusion.nii.gz \\
              -interp nearestneighbour
    done

    # 5. Extraction des moyennes
    DX_PROJ_L=\$(fslmeants -i ${dxx} -m ${sub_id}_ROI_PROJ_L_in_Diffusion.nii.gz)
    DX_PROJ_R=\$(fslmeants -i ${dxx} -m ${sub_id}_ROI_PROJ_R_in_Diffusion.nii.gz)
    DX_ASSOC_L=\$(fslmeants -i ${dxx} -m ${sub_id}_ROI_ASSOC_L_in_Diffusion.nii.gz)
    DX_ASSOC_R=\$(fslmeants -i ${dxx} -m ${sub_id}_ROI_ASSOC_R_in_Diffusion.nii.gz)
    
    DY_PROJ_L=\$(fslmeants -i ${dyy} -m ${sub_id}_ROI_PROJ_L_in_Diffusion.nii.gz)
    DY_PROJ_R=\$(fslmeants -i ${dyy} -m ${sub_id}_ROI_PROJ_R_in_Diffusion.nii.gz)

    DZ_ASSOC_L=\$(fslmeants -i ${dzz} -m ${sub_id}_ROI_ASSOC_L_in_Diffusion.nii.gz)
    DZ_ASSOC_R=\$(fslmeants -i ${dzz} -m ${sub_id}_ROI_ASSOC_R_in_Diffusion.nii.gz)

    # 6. Calcul de l'ALPS Index
    python3 -c "
alps_L = (float(\$DX_PROJ_L) + float(\$DX_ASSOC_L)) / (float(\$DY_PROJ_L) + float(\$DZ_ASSOC_L))
alps_R = (float(\$DX_PROJ_R) + float(\$DX_ASSOC_R)) / (float(\$DY_PROJ_R) + float(\$DZ_ASSOC_R))
alps_mean = (alps_L + alps_R) / 2

with open('${sub_id}_ALPS_index.csv', 'w') as f:
    f.write('subject,ALPS_Left,ALPS_Right,ALPS_Mean\\n')
    f.write('${sub_id},%f,%f,%f\\n' % (alps_L, alps_R, alps_mean))
"
    """
}
