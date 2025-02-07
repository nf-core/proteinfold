//
// Download all the required RosettaFold2NA databases and parameters
//

include {
    ARIA2_UNCOMPRESS as ARIA2_UNIREF30
    ARIA2_UNCOMPRESS as ARIA2_BFD
    ARIA2_UNCOMPRESS as ARIA2_PDB100
    ARIA2_UNCOMPRESS as ARIA2_RNA
} from './aria2_uncompress'

workflow PREPARE_ROSETTAFOLD2NA_DBS {

    take:
    rosettafold2na_db
    uniref30_rosettafold2na_path // directory: /path/to/uniref30/rosettafold2na/
    bfd_rosettafold2na_path      // directory: /path/to/bfd/
    pdb100_rosettafold2na_path
    rna_rosettafold2na_path
    uniref30_rosettafold2na_link
    bfd_rosettafold2na_link
    pdb100_rosettafold2na_link
    rna_rosettafold2na_link

    main:
    ch_versions = Channel.empty()

    if (rosettafold2na_db) {
        ch_uniref30 = Channel.value(file(uniref30_rosettafold2na_path))
        ch_bfd      = Channel.value(file(bfd_rosettafold2na_path))
        ch_pdb100   = Channel.value(file(pdb100_rosettafold2na_path))
        ch_rna      = Channel.value(file(rna_rosettafold2na_path))
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

        ARIA2_RNA(rna_rosettafold2na_link)
        ch_rna = ARIA2_RNA.out.db
        ch_versions = ch_versions.mix(ARIA2_RNA.out.versions)
    }

    emit:
    uniref30 = ch_uniref30
    bfd      = ch_bfd
    pdb100   = ch_pdb100
    rna      = ch_rna
    versions = ch_versions
}