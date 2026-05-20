process RESAMPLE_T1 {
    tag "$sub_id"
    publishDir "${params.out_dir}/${sub_id}/anat", mode: 'copy'

    input:
    tuple val(sub_id), path(t1_raw)

    output:
    
    tuple val(sub_id), path("${sub_id}_T1_resampled.nii.gz"), emit: t1_resampled

    script:
    """
    mrgrid $t1_raw regrid -voxel 1.0 ${sub_id}_T1_resampled.nii.gz -force
    """
}