//
// Prepare RoseTTAFold2NA databases
//

include {
    ARIA2_UNCOMPRESS as ARIA2_UNIREF30
    ARIA2_UNCOMPRESS as ARIA2_BFD
    ARIA2_UNCOMPRESS as ARIA2_PDB100
    ARIA2_UNCOMPRESS as ARIA2_WEIGHTS
} from './aria2_uncompress'

include { ARIA2 as ARIA2_PDB_SEQRES } from '../../modules/nf-core/aria2/main'
include { DOWNLOAD_RNA_DATABASES } from '../../modules/local/download_rna_rf2na'

workflow PREPARE_ROSETTAFOLD2NA_DBS {

    take:
    rosettafold2na_db
    bfd_rosettafold2na_path
    uniref30_rosettafold2na_path
    pdb100_rosettafold2na_path
    rna_rosettafold2na_path
    rf2na_weights_path
    bfd_rosettafold2na_link
    uniref30_rosettafold2na_link
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
        ch_bfd      = Channel.value(file(bfd_rosettafold2na_path))
        ch_uniref30 = Channel.value(file(uniref30_rosettafold2na_path))
        ch_pdb100   = Channel.value(file(pdb100_rosettafold2na_path))
        ch_rf2na_weights = Channel.value(file(rf2na_weights_path))
        ch_rna      = Channel.value(file(rna_rosettafold2na_path))
    } else {
        ARIA2_BFD(bfd_rosettafold2na_link)
        ch_bfd = ARIA2_BFD.out.db
        ch_versions = ch_versions.mix(ARIA2_BFD.out.versions)

        ARIA2_UNIREF30(uniref30_rosettafold2na_link)
        ch_uniref30 = ARIA2_UNIREF30.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF30.out.versions)

        ARIA2_PDB100(pdb100_rosettafold2na_link)
        ch_pdb100 = ARIA2_PDB100.out.db
        ch_versions = ch_versions.mix(ARIA2_PDB100.out.versions)

        DOWNLOAD_RNA_DATABASES(
            rfam_full_region_link,
            rfam_cm_link,
            rnacentral_rfam_annotations_link,
            rnacentral_id_mapping_link,
            rnacentral_sequences_link
        )
        ch_rna = DOWNLOAD_RNA_DATABASES.out.ch_db
        ch_versions = ch_versions.mix(DOWNLOAD_RNA_DATABASES.out.versions)

        ARIA2_WEIGHTS(rf2na_weights_link)
        ch_rf2na_weights = ARIA2_WEIGHTS.out.db
        ch_versions = ch_versions.mix(ARIA2_WEIGHTS.out.versions)

    }

    emit:
    bfd             = ch_bfd
    uniref30        = ch_uniref30
    pdb100          = ch_pdb100
    rna             = ch_rna
    rf2na_weights   = ch_rf2na_weights
    versions        = ch_versions
}
