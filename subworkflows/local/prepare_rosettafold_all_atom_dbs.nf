//
// Download all the required Rosettafold-All-Atom databases and parameters
//

include { ARIA2_UNCOMPRESS as ARIA2_UNIREF30  } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_BFD       } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_SMALL_BFD } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_PDB100    } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_WEIGHTS   } from './aria2_uncompress'

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
    if (rosettafold_all_atom_db) {
        ch_bfd                  = channel.value(files(rosettafold_all_atom_bfd_path, checkIfExists: true))
        ch_uniref30             = channel.value(files(rosettafold_all_atom_uniref30_path, checkIfExists: true))
        ch_pdb100               = channel.value(files(rosettafold_all_atom_pdb100_path, checkIfExists: true))
        ch_rfaa_paper_weights   = channel.value(files(rosettafold_all_atom_paper_weights_path, checkIfExists: true))
    }
    else {
        ARIA2_BFD(rosettafold_all_atom_bfd_link)
        ch_bfd = ARIA2_BFD
                    .out
                    .db
                    .map {
                        dir -> dir.listFiles().findAll { it -> it.isFile() }
                    }

        ARIA2_UNIREF30(rosettafold_all_atom_uniref30_link)
        ch_uniref30 = ARIA2_UNIREF30
                        .out
                        .db
                        .map {
                            dir -> dir.listFiles().findAll { it -> it.isFile() }
                        }

        ARIA2_PDB100(rosettafold_all_atom_pdb100_link)
        ch_pdb100 = ARIA2_PDB100
                        .out
                        .db
                        .map {
                            dir -> dir.listFiles().findAll { it -> it.isFile() }
                        }

        ARIA2_WEIGHTS(rosettafold_all_atom_paper_weights_link)
        ch_rfaa_paper_weights = ARIA2_WEIGHTS.out.db
    }

    emit:
    bfd                 = ch_bfd
    uniref30            = ch_uniref30
    pdb100              = ch_pdb100
    rfaa_paper_weights  = ch_rfaa_paper_weights
}
