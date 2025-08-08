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
    rosettafold_all_atom_bfd_path      // directory: /path/to/bfd/
    rosettafold_all_atom_uniref30_path // directory: /path/to/uniref30/rosettafold_all_atom/
    rosettafold_all_atom_pdb100_path
    rosettafold_all_atom_paper_weights_path
    rosettafold_all_atom_bfd_link
    rosettafold_all_atom_uniref30_link
    rosettafold_all_atom_pdb100_link
    rosettafold_all_atom_paper_weights_link

    main:
    ch_versions                 = Channel.empty()

    if (rosettafold_all_atom_db) {
        ch_bfd                  = Channel.value(file(rosettafold_all_atom_bfd_path))
        ch_uniref30             = Channel.value(file(rosettafold_all_atom_uniref30_path))
        ch_pdb100               = Channel.value(file(rosettafold_all_atom_pdb100_path))
        ch_rfaa_paper_weights   = Channel.value(file(rosettafold_all_atom_paper_weights_path))
    }
    else {
        ARIA2_BFD(rosettafold_all_atom_bfd_link)
        ch_bfd = ARIA2_BFD.out.db
        ch_versions = ch_versions.mix(ARIA2_BFD.out.versions)

        ARIA2_UNIREF30(rosettafold_all_atom_uniref30_link)
        ch_uniref30 = ARIA2_UNIREF30.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF30.out.versions)

        ARIA2_PDB100(rosettafold_all_atom_pdb100_link)
        ch_pdb100 = ARIA2_PDB100.out.db
        ch_versions = ch_versions.mix(ARIA2_PDB100.out.versions)

        ARIA2_WEIGHTS(rosettafold_all_atom_paper_weights_link)
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
