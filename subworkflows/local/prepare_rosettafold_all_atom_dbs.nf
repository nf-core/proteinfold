//
// Download all the required Rosettafold-All-Atom databases and parameters
//

include {
    ARIA2_UNCOMPRESS as ARIA2_UNIREF30
    ARIA2_UNCOMPRESS as ARIA2_BFD
    ARIA2_UNCOMPRESS as ARIA2_SMALL_BFD
    ARIA2_UNCOMPRESS as ARIA2_PDB100
    ARIA2_UNCOMPRESS as ARIA2_WEIGHTS
} from './aria2_uncompress'

include { ARIA2 as ARIA2_PDB_SEQRES } from '../../modules/nf-core/aria2/main'

workflow PREPARE_ROSETTAFOLD_ALL_ATOM_DBS {

    take:
    rosettafold_all_atom_db
    bfd_rosettafold_all_atom_path      // directory: /path/to/bfd/
    uniref30_rosettafold_all_atom_path // directory: /path/to/uniref30/rosettafold_all_atom/
    pdb100_rosettafold_all_atom_path
    rfaa_paper_weights_path
    bfd_rosettafold_all_atom_link
    uniref30_rosettafold_all_atom_link
    pdb100_rosettafold_all_atom_link
    rfaa_paper_weights_link

    main:
    ch_versions                 = Channel.empty()

    if (rosettafold_all_atom_db) {
        ch_bfd                  = Channel.value(file(bfd_rosettafold_all_atom_path))
        ch_uniref30             = Channel.value(file(uniref30_rosettafold_all_atom_path))
        ch_pdb100               = Channel.value(file(pdb100_rosettafold_all_atom_path))
        ch_rfaa_paper_weights   = Channel.value(file(rfaa_paper_weights_path))
    }
    else {
        ARIA2_BFD(bfd_rosettafold_all_atom_link)
        ch_bfd = ARIA2_BFD.out.db
        ch_versions = ch_versions.mix(ARIA2_BFD.out.versions)

        ARIA2_UNIREF30(uniref30_rosettafold_all_atom_link)
        ch_uniref30 = ARIA2_UNIREF30.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF30.out.versions)

        ARIA2_PDB100(pdb100_rosettafold_all_atom_link)
        ch_pdb100 = ARIA2_PDB100.out.db
        ch_versions = ch_versions.mix(ARIA2_PDB100.out.versions)

        ARIA2_WEIGHTS(rfaa_paper_weights_link)
        ch_rfaa_paper_weights = ARIA2_WEIGHTS.out.db
        ch_versions = ch_versions.mix(ARIA2_WEIGHTS.out.versions)
    }

    emit:
    bfd                 = ch_bfd
    uniref30            = ch_uniref30
    pdb100              = ch_pdb100
    rfaa_paper_weights  = ch_rfaa_paper_weights
    versions            = ch_versions
}
