//
// Download the files required for Protenix
//
include { ARIA2 as ARIA2_PROTENIX_MODEL     } from '../../modules/nf-core/aria2/main'
include { ARIA2 as ARIA2_PROTENIX_CCD       } from '../../modules/nf-core/aria2/main'
include { ARIA2 as ARIA2_PROTENIX_CCD_RDKIT } from '../../modules/nf-core/aria2/main'
include { ARIA2 as ARIA2_PROTENIX_CLUSTERS  } from '../../modules/nf-core/aria2/main'
include { ARIA2 as ARIA2_PROTENIX_OBSOLETE  } from '../../modules/nf-core/aria2/main'

workflow PREPARE_PROTENIX_DBS {
    take:
    protenix_db
    protenix_model_path
    protenix_ccd_path
    protenix_ccd_rdkit_path
    protenix_clusters_path
    protenix_obsolete_path
    protenix_model_link
    protenix_ccd_link
    protenix_ccd_rdkit_link
    protenix_clusters_link
    protenix_obsolete_link

    main:
    ch_versions     = channel.empty()

    if (protenix_db) {
        ch_protenix_model     = channel.value(file(protenix_model_path, checkIfExists: true))
        ch_protenix_ccd       = channel.value(file(protenix_ccd_path, checkIfExists: true))
        ch_protenix_ccd_rdkit = channel.value(file(protenix_ccd_rdkit_path, checkIfExists: true))
        ch_protenix_clusters  = channel.value(file(protenix_clusters_path, checkIfExists: true))
        ch_protenix_obsolete  = channel.value(file(protenix_obsolete_path, checkIfExists: true))
    } else {
        ARIA2_PROTENIX_MODEL(
            [
                [:],
                protenix_model_link
            ]
        )
        ch_protenix_model = ARIA2_PROTENIX_MODEL.out.downloaded_file.map { it -> it[1] }
        ch_versions = ch_versions.mix(ARIA2_PROTENIX_MODEL.out.versions)

        ARIA2_PROTENIX_CCD(
            [
                [:],
                protenix_ccd_link
            ]
        )
        ch_protenix_ccd = ARIA2_PROTENIX_CCD.out.downloaded_file.map { it -> it[1] }
        ch_versions = ch_versions.mix(ARIA2_PROTENIX_CCD.out.versions)

        ARIA2_PROTENIX_CCD_RDKIT(
            [
                [:],
                protenix_ccd_rdkit_link
            ]
        )
        ch_protenix_ccd_rdkit = ARIA2_PROTENIX_CCD_RDKIT.out.downloaded_file.map { it -> it[1] }
        ch_versions = ch_versions.mix(ARIA2_PROTENIX_CCD_RDKIT.out.versions)

        ARIA2_PROTENIX_CLUSTERS(
            [
                [:],
                protenix_clusters_link
            ]
        )
        ch_protenix_clusters = ARIA2_PROTENIX_CLUSTERS.out.downloaded_file.map { it -> it[1] }
        ch_versions = ch_versions.mix(ARIA2_PROTENIX_CLUSTERS.out.versions)

        ARIA2_PROTENIX_OBSOLETE(
            [
                [:],
                protenix_obsolete_link
            ]
        )
        ch_protenix_obsolete = ARIA2_PROTENIX_OBSOLETE.out.downloaded_file.map { it -> it[1] }
        ch_versions = ch_versions.mix(ARIA2_PROTENIX_OBSOLETE.out.versions)
    }

    emit:
    protenix_model     = ch_protenix_model
    protenix_ccd       = ch_protenix_ccd
    protenix_ccd_rdkit = ch_protenix_ccd_rdkit
    protenix_clusters  = ch_protenix_clusters
    protenix_obsolete  = ch_protenix_obsolete
    versions           = ch_versions
}
