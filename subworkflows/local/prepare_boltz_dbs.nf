//
// Download the files required for Boltz
//

include {
        ARIA2 as ARIA2_BOLTZ_CCD
        ARIA2 as ARIA2_BOLTZ_MODEL } from '../../modules/nf-core/aria2/main'

workflow PREPARE_BOLTZ_DBS {
    take:
    boltz_ccd
    boltz_model
    boltz_ccd_link
    boltz_model_link

    main:
    ch_versions     = Channel.empty()

    if (boltz_ccd) {
        ch_boltz_ccd = Channel.value(file(boltz_ccd))
        ch_boltz_model = Channel.value(file(boltz_model))
    } else {
        ARIA2_BOLTZ_CCD(
            [
                [:],
                boltz_ccd_link
            ]
        )
        ch_boltz_ccd = ARIA2_BOLTZ_CCD.out.downloaded_file.map{ it[1] }
        ch_versions = ch_versions.mix(ARIA2_BOLTZ_CCD.out.versions)

        ARIA2_BOLTZ_MODEL(
            [
                [:],
                boltz_model_link
            ]
        )
        ch_boltz_model = ARIA2_BOLTZ_MODEL.out.downloaded_file.map{ it[1] }
        ch_versions = ch_versions.mix(ARIA2_BOLTZ_MODEL.out.versions)
    }

    emit:
    boltz_ccd    = ch_boltz_ccd
    boltz_model  = ch_boltz_model
    versions     = ch_versions
}
