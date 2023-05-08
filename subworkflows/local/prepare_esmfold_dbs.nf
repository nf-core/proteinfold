//
// Download all the required Esmfold parameters
//

include { ARIA2 as ARIA2_ESMFOLD_3B_V1                        } from '../../modules/nf-core/aria2/main'
include { ARIA2 as ARIA2_ESM2_T36_3B_UR50D                    } from '../../modules/nf-core/aria2/main'
include { ARIA2 as ARIA2_ESM2_T36_3B_UR50D_CONTACT_REGRESSION } from '../../modules/nf-core/aria2/main'
include { PARAMS_TO_DIR } from '../../modules/local/params_to_dir'

workflow PREPARE_ESMFOLD_DBS {
    main:
    ch_versions   = Channel.empty()

    if (params.esmfold_db) {
        ch_params     = file( params.esmfold_params_path, type: 'dir' )
    }
    else {
        ARIA2_ESMFOLD_3B_V1 (
            params.esmfold_3B_v1
        )
        ARIA2_ESM2_T36_3B_UR50D (
            params.esm2_t36_3B_UR50D
        )
        ARIA2_ESM2_T36_3B_UR50D_CONTACT_REGRESSION (
            params.esm2_t36_3B_UR50D_contact_regression
        )
        collect_params = ARIA2_ESMFOLD_3B_V1.out.downloaded_file.mix(ARIA2_ESM2_T36_3B_UR50D.out.downloaded_file,ARIA2_ESM2_T36_3B_UR50D_CONTACT_REGRESSION.out.downloaded_file).collect()
        ch_versions = ch_versions.mix(ARIA2_ESMFOLD_3B_V1.out.versions)
        PARAMS_TO_DIR (
            collect_params
        )
        ch_params = PARAMS_TO_DIR.out.input_models
        ch_versions = ch_versions.mix(PARAMS_TO_DIR.out.versions)
    }

	emit:
    params     = ch_params
    versions   = ch_versions
}
