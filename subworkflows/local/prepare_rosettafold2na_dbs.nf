//
// Download all the required RosettaFold2NA databases and parameters
//

include {
    ARIA2_UNCOMPRESS as ARIA2_UNIREF30
    ARIA2_UNCOMPRESS as ARIA2_BFD
    ARIA2_UNCOMPRESS as ARIA2_PDB100
    ARIA2_UNCOMPRESS as ARIA2_WEIGHTS
} from './aria2_uncompress'

include { GUNZIP as GUNZIP_RFAM_CM } from '../../modules/nf-core/gunzip/main'
include { CMPRESS } from '../../modules/local/cmpress'
include { REPROCESS_RNAC } from '../../modules/local/reprocess_rnac'
include { MAKEBLASTDB } from '../../modules/local/makeblastdb'
include { UPDATE_BLASTDB } from '../../modules/local/update_blastdb'

workflow PREPARE_ROSETTAFOLD2NA_DBS {

    take:
    rosettafold2na_db
    uniref30_rosettafold2na_path
    bfd_rosettafold2na_path
    pdb100_rosettafold2na_path
    rf2na_weights_path
    uniref30_rosettafold2na_link
    bfd_rosettafold2na_link
    pdb100_rosettafold2na_link
    rf2na_weights_link
    rfam_full_region_link
    rfam_cm_link
    rnacentral_rfam_annotations_link
    rnacentral_id_mapping_link
    rnacentral_sequences_link

    main:
    ch_versions = Channel.empty()

    if (rosettafold2na_db) {
        ch_uniref30 = Channel.value(file(uniref30_rosettafold2na_path))
        ch_bfd      = Channel.value(file(bfd_rosettafold2na_path))
        ch_pdb100   = Channel.value(file(pdb100_rosettafold2na_path))
        ch_weights  = Channel.value(file(rf2na_weights_path))
    }
    else {
        ARIA2_UNIREF30(uniref30_rosettafold2na_link)
        ch_uniref30 = ARIA2_UNIREF30.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF30.out.versions)

        ARIA2_BFD(bfd_rosettafold2na_link)
        ch_bfd = ARIA2_BFD.out.db
        ch_versions = ch_versions.mix(ARIA2_BFD.out.versions)

        ARIA2_PDB100(pdb100_rosettafold2na_link)
        ch_pdb100 = ARIA2_PDB100.out.db
        ch_versions = ch_versions.mix(ARIA2_PDB100.out.versions)

        ARIA2_WEIGHTS(rf2na_weights_link)
        ch_weights = ARIA2_WEIGHTS.out.db
        ch_versions = ch_versions.mix(ARIA2_WEIGHTS.out.versions)

        // RNA databases processing
        GUNZIP_RFAM_CM(rfam_cm_link)
        CMPRESS(GUNZIP_RFAM_CM.out.gunzip)
        ch_versions = ch_versions.mix(CMPRESS.out.versions)

        REPROCESS_RNAC(
            rnacentral_id_mapping_link,
            rnacentral_rfam_annotations_link
        )
        ch_versions = ch_versions.mix(REPROCESS_RNAC.out.versions)

        MAKEBLASTDB(rnacentral_sequences_link)
        ch_versions = ch_versions.mix(MAKEBLASTDB.out.versions)

        UPDATE_BLASTDB()
        ch_versions = ch_versions.mix(UPDATE_BLASTDB.out.versions)
    }

    emit:
    uniref30 = ch_uniref30
    bfd      = ch_bfd
    pdb100   = ch_pdb100
    weights  = ch_weights
    rfam_cm  = CMPRESS.out.cmpress
    rnac     = REPROCESS_RNAC.out.reprocessed
    rnacentral_blast = MAKEBLASTDB.out.db
    nt       = UPDATE_BLASTDB.out.db
    versions = ch_versions
}