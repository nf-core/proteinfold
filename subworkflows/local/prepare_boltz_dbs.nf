//
// Download the files required for Boltz
//
include { ARIA2 as ARIA2_BOLTZ_CCD   } from '../../modules/nf-core/aria2/main'
include { ARIA2 as ARIA2_BOLTZ_MODEL } from '../../modules/nf-core/aria2/main'
include { ARIA2 as ARIA2_BOLTZ2_AFF  } from '../../modules/nf-core/aria2/main'
include { ARIA2 as ARIA2_BOLTZ2_CONF } from '../../modules/nf-core/aria2/main'

include { ARIA2_UNCOMPRESS } from './aria2_uncompress'

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
    ch_versions     = channel.empty()

    if (boltz_db) {
        ch_boltz_ccd    = channel.value(file(boltz_ccd, checkIfExists: true))
        ch_boltz_model  = channel.value(file(boltz_model, checkIfExists: true))
        ch_boltz2_aff   = channel.value(file(boltz2_aff, checkIfExists: true))
        ch_boltz2_conf  = channel.value(file(boltz2_conf, checkIfExists: true))
        ch_boltz2_mols  = channel.value(file(boltz2_mols, checkIfExists: true))
    } else {
        ARIA2_BOLTZ_CCD(
            [
                [:],
                boltz_ccd_link
            ]
        )
        ch_boltz_ccd = ARIA2_BOLTZ_CCD.out.downloaded_file.map { it -> it[1] }
        ch_versions = ch_versions.mix(ARIA2_BOLTZ_CCD.out.versions)

        ARIA2_BOLTZ_MODEL(
            [
                [:],
                boltz_model_link
            ]
        )
        ch_boltz_model = ARIA2_BOLTZ_MODEL.out.downloaded_file.map { it ->  it[1] }
        ch_versions = ch_versions.mix(ARIA2_BOLTZ_MODEL.out.versions)

        ARIA2_BOLTZ2_AFF(
            [
                [:],
                boltz2_aff_link
            ]
        )
        ch_boltz2_aff = ARIA2_BOLTZ2_AFF.out.downloaded_file.map { it -> it[1] }
        ch_versions = ch_versions.mix(ARIA2_BOLTZ2_AFF.out.versions)

        ARIA2_BOLTZ2_CONF(
            [
                [:],
                boltz2_conf_link
            ]
        )
        ch_boltz2_conf = ARIA2_BOLTZ2_CONF.out.downloaded_file.map { it -> it[1] }
        ch_versions = ch_versions.mix(ARIA2_BOLTZ2_CONF.out.versions)

	ARIA2_UNCOMPRESS(
                boltz2_mols_link
        )
        ch_boltz2_mols = ARIA2_UNCOMPRESS.out.db
        ch_versions = ch_versions.mix(ARIA2_UNCOMPRESS.out.versions)
    }

    emit:
    boltz_ccd    = ch_boltz_ccd
    boltz_model  = ch_boltz_model
    boltz2_aff   = ch_boltz2_aff
    boltz2_conf  = ch_boltz2_conf
    boltz2_mols  = ch_boltz2_mols
    versions     = ch_versions
}
