//
// Download all the required AlphaFold 3 databases and parameters
//

include { ARIA2_UNCOMPRESS as ARIA2_SMALL_BFD  } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_MGNIFY     } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_MMCIF      } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_UNIREF90   } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_PDB_SEQRES } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_UNIPROT    } from './aria2_uncompress'

include { DOWNLOAD_PDBMMCIF_AF3 } from '../../modules/local/download_pdbmmcif_af3'

workflow PREPARE_ALPHAFOLD3_DBS {

    take:
    alphafold3_db          // directory: path to alphafold3 DBs
    alphafold3_params_path // directory: /path/to/alphafold3/params/
    small_bfd_path         // directory: /path/to/small_bfd/
    mgnify_path            // directory: /path/to/mgnify/
    pdb_mmcif_path         // directory: /path/to/pdb_mmcif/
    uniref90_path          // directory: /path/to/uniref90/
    pdb_seqres_path        // directory: /path/to/pdb_seqres/
    uniprot_path           // directory: /path/to/uniprot/
    small_bfd_link         //    string: Specifies the link to download small_bfd
    mgnify_link            //    string: Specifies the link to download mgnify
    pdb_mmcif_link         //    string: Specifies the link to download mmcif
    uniref90_link          //    string: Specifies the link to download uniref90
    pdb_seqres_link        //    string: Specifies the link to download pdb_seqres
    uniprot_link           //    string: Specifies the link to download uniprot

    main:
    ch_versions   = Channel.empty()

    if (alphafold3_db) {
        ch_params         = Channel.value(file(alphafold3_params_path, checkIfExists: true))
        ch_small_bfd      = Channel.value(file(small_bfd_path, checkIfExists: true))
        ch_mgnify         = Channel.value(file(mgnify_path, checkIfExists: true))
        ch_mmcif          = Channel.value(file(pdb_mmcif_path, checkIfExists: true))
        ch_uniref90       = Channel.value(file(uniref90_path))
        ch_pdb_seqres     = Channel.value(file(pdb_seqres_path))
        ch_uniprot        = Channel.value(file(uniprot_path))
    } else {

        ARIA2_SMALL_BFD (
            small_bfd_link
        )
        ch_small_bfd = ARIA2_SMALL_BFD.out.db
        ch_versions  = ch_versions.mix(ARIA2_SMALL_BFD.out.versions)

        ch_params = Channel.value(file(alphafold3_params_path, checkIfExists: true))

        ARIA2_MGNIFY (
            mgnify_link
        )
        ch_mgnify   = ARIA2_MGNIFY.out.db
        ch_versions = ch_versions.mix(ARIA2_MGNIFY.out.versions)

        ARIA2_MMCIF (
            pdb_mmcif_link
        )
        ch_mmcif    = ARIA2_MMCIF.out.db
        ch_versions = ch_versions.mix(ARIA2_MMCIF.out.versions)

        DOWNLOAD_PDBMMCIF_AF3(
            pdb_mmcif_link
        )
        ch_mmcif    = DOWNLOAD_PDBMMCIF_AF3.out.ch_db
        ch_versions = ch_versions.mix(DOWNLOAD_PDBMMCIF_AF3.out.versions)

        ARIA2_UNIREF90 (
            uniref90_link
        )
        ch_uniref90 = ARIA2_UNIREF90.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF90.out.versions)

        ARIA2_PDB_SEQRES (
            pdb_seqres_link
        )
        ch_pdb_seqres = ARIA2_PDB_SEQRES.out.db
        ch_versions   = ch_versions.mix(ARIA2_PDB_SEQRES.out.versions)

        ARIA2_UNIPROT (
            uniprot_link
        )
        ch_uniprot  = ARIA2_UNIPROT.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIPROT.out.versions)
    }

    emit:
    params     = ch_params
    small_bfd  = ch_small_bfd
    mgnify     = ch_mgnify
    pdb_mmcif  = ch_mmcif
    uniref90   = ch_uniref90
    pdb_seqres = ch_pdb_seqres
    uniprot    = ch_uniprot
    versions   = ch_versions
}
