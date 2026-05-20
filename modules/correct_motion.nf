process CREATE_MASK {
    tag "${sub_id}"
    cpus 4

    input:
    tuple val(sub_id), path(b0_vrt)

    output:
    tuple val(sub_id), path("${sub_id}_mask.nii.gz")

    script:
    """

    bet ${b0_vrt} brain -m -n -f 0.3
    
    mv brain_mask.nii.gz ${sub_id}_mask.nii.gz
    """
}
process EDDY {
    tag "${sub_id}"
    label 'gpu'
    publishDir "${params.out_dir}/${sub_id}/preprocess", mode: 'copy'

    input:
    tuple val(sub_id), path(dwi), path(bval), path(bvec), path(mask), path(topup_files), path(acqparams)

    output:
    tuple val(sub_id), path("${sub_id}_eddy_corr.nii.gz"), emit: dwi_corrected
    tuple val(sub_id), path("${sub_id}_eddy_rotated.bvecs"), emit: bvecs_rotated

    script:
    """
    # --- LOAD BALANCING GPU ---

    export CUDA_VISIBLE_DEVICES=\$((${task.index} % 2))

    # 1. Create index file
    num_vols=\$(wc -w < ${bval})
    for i in \$(seq 1 \$num_vols); do echo 1 >> index.txt; done

    # 2. Dynamic extraction of TOPUP prefix
    FIRST_TOPUP_FILE=\$(echo "${topup_files}" | awk '{print \$1}')
    TOPUP_PREFIX=\$(echo \$FIRST_TOPUP_FILE | sed 's/_fieldcoef.nii.gz//' | sed 's/_movpar.txt//')
    
    # 3. Launch Eddy_cuda
    eddy_cuda \\
        --imain=${dwi} \\
        --mask=${mask} \\
        --acqp=${acqparams} \\
        --index=index.txt \\
        --bvecs=${bvec} \\
        --bvals=${bval} \\
        --topup=\$TOPUP_PREFIX \\
        --out=${sub_id}_eddy_corr \\
        --repol \\
        --data_is_shelled \\
        --verbose
        
    # 4. Rename output
    mv ${sub_id}_eddy_corr.eddy_rotated_bvecs ${sub_id}_eddy_rotated.bvecs
    """
}
