process DENOISING {
    tag "${sub_id}"
    cpus 8

    input:
    tuple val(sub_id), path(dwi)

    output:
    tuple val(sub_id), path("${sub_id}_denoised.mif"), path("${sub_id}_noise.mif")

    script:
    """
    dwidenoise ${dwi} ${sub_id}_denoised.mif -noise ${sub_id}_noise.mif
    """
}

process GIBBS_UNRINGING {
    tag "${sub_id}"
    cpus 4

    input:
    tuple val(sub_id), path(denoised_mif), path(noise_mif)

    output:
    tuple val(sub_id), path("${sub_id}_unringed.mif"), path(noise_mif)

    script:
    """
    mrdegibbs ${denoised_mif} ${sub_id}_unringed.mif
    """
}

process RICIAN_CORRECTION {
    tag "${sub_id}"
    publishDir "${params.out_dir}/${sub_id}/preprocess", mode: 'copy'

    input:
    tuple val(sub_id), path(unringed_mif), path(noise_mif)

    output:
    tuple val(sub_id), path("${sub_id}_clean.nii.gz")

    script:
    """
    mrcalc ${unringed_mif} 2 -pow ${noise_mif} 2 -pow -sub 0 -max -sqrt ${sub_id}_clean.nii.gz
    """
}

process BIAS_CORRECTION {
    tag "${sub_id}"
    label 'cpu_high'
    publishDir "${params.out_dir}/${sub_id}/preprocess", mode: 'copy'

    input:
    tuple val(sub_id), path(dwi), path(bval), path(bvec), path(mask)

    output:
    tuple val(sub_id), path("${sub_id}_dwi_n4.nii.gz"), emit: dwi_n4

    script:
    """
    # 1. Harmonisation du masque avec le DWI (Eddy-corrected)
    # On s'assure que le masque a EXACTEMENT le même header que l'image
    mrgrid ${mask} regrid -template ${dwi} mask_harmonized.nii.gz -force

    # 2. Correction du champ de biais avec ANTs
    # On utilise le masque harmonisé
    dwibiascorrect ants ${dwi} ${sub_id}_dwi_n4.nii.gz \
        -fslgrad ${bvec} ${bval} \
        -mask mask_harmonized.nii.gz \
        -force
    """
}
