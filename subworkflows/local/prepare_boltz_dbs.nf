//
// Download the files required for Boltz
//

include {
        ARIA2 as ARIA2_BOLTZ_CCD
        ARIA2 as ARIA2_BOLTZ_MODEL
        ARIA2 as ARIA2_BOLTZ2_AFF
        ARIA2 as ARIA2_BOLTZ2_CONF
        ARIA2 as ARIA2_MOLS
} from '../../modules/nf-core/aria2/main'

workflow PREPARE_BOLTZ_DBS {
    take:
    boltz_db
    boltz_ccd
    boltz_model
    boltz2_aff
    boltz2_conf
    boltz2_mols
    boltz_ccd_link
    boltz_model_link
    boltz2_aff_link
    boltz2_conf_link
    boltz2_mols_link

    main:
    ch_versions     = Channel.empty()

    if (boltz_db) {
        ch_boltz_ccd    = Channel.value(file(boltz_ccd))
        ch_boltz_model  = Channel.value(file(boltz_model))
        ch_boltz2_aff   = Channel.value(file(boltz2_aff))
        ch_boltz2_conf  = Channel.value(file(boltz2_conf))
        ch_boltz2_mols  = Channel.value(file(boltz2_mols))
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

        ARIA2_BOLTZ2_AFF(
            [
                [:],
                boltz2_aff_link
            ]
        )
        ch_boltz2_aff = ARIA2_BOLTZ2_AFF.out.downloaded_file.map{ it[1] }
        ch_versions = ch_versions.mix(ARIA2_BOLTZ2_AFF.out.versions)

        ARIA2_BOLTZ2_CONF(
            [
                [:],
                boltz2_conf_link
            ]
        )
        ch_boltz2_conf = ARIA2_BOLTZ2_CONF.out.downloaded_file.map{ it[1] }
        ch_versions = ch_versions.mix(ARIA2_BOLTZ2_CONF.out.versions)

        ARIA2_MOLS(
            [
                [:],
                boltz2_mols_link
            ]
        )
        ch_boltz2_mols = ARIA2_MOLS.out.downloaded_file.map{ it[1] }
        ch_versions = ch_versions.mix(ARIA2_MOLS.out.versions)
    }

    emit:
    boltz_ccd    = ch_boltz_ccd
    boltz_model  = ch_boltz_model
    boltz2_aff   = ch_boltz2_aff
    boltz2_conf  = ch_boltz2_conf
    boltz2_mols  = ch_boltz2_mols
    versions     = ch_versions
}
