nextflow.enable.dsl = 2

// --- IMPORTS ---
include { RESAMPLE_T1 } from './modules/preprocessing'
include { DENOISING ; GIBBS_UNRINGING ; RICIAN_CORRECTION ; BIAS_CORRECTION } from './modules/cleaning'
include { EXTRACT_B0 ; SYNTHB0 ; REGISTER_T1_TO_B0 ; REGISTER_MNI_TO_T1 } from './modules/registration'
include { CREATE_MASK ; EDDY } from './modules/correct_motion'
include { DKI_FITTING ; CALCULATE_ALPS_INDEX } from './modules/metrics'

workflow {


    nifti_ch = channel.fromPath("${projectDir}/../inputs/sub-*/dwi/*_dwi.nii.gz").map { [it.parent.parent.name, it] }
    bval_ch = channel.fromPath("${projectDir}/../inputs/sub-*/dwi/*.bval").map { [it.parent.parent.name, it] }
    bvec_ch = channel.fromPath("${projectDir}/../inputs/sub-*/dwi/*.bvec").map { [it.parent.parent.name, it] }
    json_ch = channel.fromPath("${projectDir}/../inputs/sub-*/dwi/*.json").map { [it.parent.parent.name, it] }

    t1_ch = channel.fromPath("${projectDir}/../inputs/sub-*/anat/*_T1.nii.gz").map { [it.parent.parent.name, it] }

    dwi_all_ch = nifti_ch.join(bval_ch).join(bvec_ch).join(json_ch)

    dwi_raw_ch = dwi_all_ch.map { id, nifti, bval, bvec, json ->
        def rt = new groovy.json.JsonSlurper().parseText(json.text).EstimatedTotalReadoutTime
        return [id, nifti, bval, bvec, rt]
    }

    RESAMPLE_T1(t1_ch)

    // --- 2. PHASE 1 : NETTOYAGE ---

    cleaning_input_ch = dwi_raw_ch.map { id, nifti, bval, bvec, rt -> [id, nifti] }

    clean_dwi_ch = RICIAN_CORRECTION(GIBBS_UNRINGING(DENOISING(cleaning_input_ch)))

    // --- 3. PHASE 2 : GÉOMÉTRIE ---

    b0_extraction_ch = clean_dwi_ch.join(bval_ch).join(bvec_ch)
    b0_mean_ch = EXTRACT_B0(b0_extraction_ch)

    // SYNTHB0 : [ID, T1, B0_Mean, ReadoutTime]
    synthb0_ch = RESAMPLE_T1.out.t1_resampled
        .join(b0_mean_ch)
        .join(dwi_raw_ch.map { id, nifti, bval, bvec, rt -> [id, rt] })

    SYNTHB0(synthb0_ch)

    // --- 4. RECALAGE ANATOMIQUE (T1 -> Diffusion) ---
    reg_input_ch = RESAMPLE_T1.out.t1_resampled
        .join(SYNTHB0.out.b0_vrt)
    REGISTER_T1_TO_B0(reg_input_ch)

    CREATE_MASK(SYNTHB0.out.b0_vrt)

    //EDDY : [id, dwi, bval, bvec, mask, topup_files, acqparams]
    ch_eddy = b0_extraction_ch
        .join(CREATE_MASK.out)
        .join(SYNTHB0.out.topup_files)
        .join(SYNTHB0.out.acqparams_eddy)

    EDDY(ch_eddy)

    bias_corr_input_ch = EDDY.out.dwi_corrected
        .join(bval_ch)
        .join(EDDY.out.bvecs_rotated)
        .join(CREATE_MASK.out)

    BIAS_CORRECTION(bias_corr_input_ch)

    dki_input_ch = BIAS_CORRECTION.out.dwi_n4
        .join(bval_ch)
        .join(EDDY.out.bvecs_rotated)
        .join(CREATE_MASK.out)

    DKI_FITTING(dki_input_ch)

    // --- 5. POST-TRAITEMENT : ALPS INDEX ---
    // Recalage MNI -> T1 -> Diffusion
    mni_reg_input_ch = REGISTER_T1_TO_B0.out.t1_brain
        .join(REGISTER_T1_TO_B0.out.mat)
    
    REGISTER_MNI_TO_T1(mni_reg_input_ch)

    // ALPS : [id, b0_corr_brain, mni_to_diff_mat, dxx, dyy, dzz]
    alps_ch = REGISTER_T1_TO_B0.out.b0_brain
        .join(REGISTER_MNI_TO_T1.out.mni_to_diff_mat)
        .join(DKI_FITTING.out.for_alps)

    CALCULATE_ALPS_INDEX(alps_ch)
}
