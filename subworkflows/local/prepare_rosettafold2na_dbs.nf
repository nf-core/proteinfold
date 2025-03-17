//
// Prepare RoseTTAFold2NA databases
//

include { ARIA2_UNCOMPRESS as ARIA2_UNIREF30 } from '../../modules/local/aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_BFD      } from '../../modules/local/aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_PDB100   } from '../../modules/local/aria2_uncompress'
include { DOWNLOAD_RNA_DATABASES             } from '../../modules/local/download_rna_rf2na'

workflow PREPARE_ROSETTAFOLD2NA_DBS {
    take:
    rosettafold2na_db           // boolean: true if databases are provided, false if they need to be downloaded
    uniref30_rosettafold2na_path
    bfd_rosettafold2na_path
    pdb100_rosettafold2na_path
    rna_rosettafold2na_path
    uniref30_rosettafold2na_link
    bfd_rosettafold2na_link
    pdb100_rosettafold2na_link
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
        ch_rna      = Channel.value(file(rna_rosettafold2na_path))
    } else {
        // Download and process protein databases
        ARIA2_UNIREF30 ( uniref30_rosettafold2na_link )
        ch_uniref30 = ARIA2_UNIREF30.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF30.out.versions)

        ARIA2_BFD ( bfd_rosettafold2na_link )
        ch_bfd = ARIA2_BFD.out.db
        ch_versions = ch_versions.mix(ARIA2_BFD.out.versions)

        ARIA2_PDB100 ( pdb100_rosettafold2na_link )
        ch_pdb100 = ARIA2_PDB100.out.db
        ch_versions = ch_versions.mix(ARIA2_PDB100.out.versions)

        // Download and process RNA databases
        DOWNLOAD_RNA_DATABASES (
            rfam_full_region_link,
            rfam_cm_link,
            rnacentral_rfam_annotations_link,
            rnacentral_id_mapping_link,
            rnacentral_sequences_link
        )
        ch_rna = DOWNLOAD_RNA_DATABASES.out.rna_db
        ch_versions = ch_versions.mix(DOWNLOAD_RNA_DATABASES.out.versions)
    }

    emit:
    uniref30 = ch_uniref30
    bfd      = ch_bfd
    pdb100   = ch_pdb100
    rna      = ch_rna
    versions = ch_versions
}