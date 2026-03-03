//
// Download all the required AlphaFold 3 databases and parameters
//

include { ARIA2_UNCOMPRESS as ARIA2_SMALL_BFD             } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_MGNIFY                } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_MMCIF                 } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_UNIREF90              } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_PDB_SEQRES            } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_UNIPROT               } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_RNACENTRAL_ACTIVE_SEQ } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_NT_RNA_2023_02_23     } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_RFAM                  } from './aria2_uncompress'

include { DOWNLOAD_PDBMMCIF_AF3 } from '../../modules/local/download_pdbmmcif_af3'

workflow PREPARE_ALPHAFOLD3_DBS {

    take:
    alphafold3_db              // directory: path to alphafold3 DBs
    alphafold3_params_path     // directory: /path/to/alphafold3/params/
    small_bfd_path             // directory: /path/to/small_bfd/
    mgnify_path                // directory: /path/to/mgnify/
    pdb_mmcif_path             // directory: /path/to/pdb_mmcif/
    uniref90_path              // directory: /path/to/uniref90/
    pdb_seqres_path            // directory: /path/to/pdb_seqres/
    uniprot_path               // directory: /path/to/uniprot/
    rnacentral_active_seq_path // directory: /path/to/rnacentral_active_seq/
    nt_rna_2023_02_23_path     // directory: /path/to/nt_rna_2023_02_23/
    rfam_path                  // directory: /path/to/rfam/
    small_bfd_link             //    string: Specifies the link to download small_bfd
    mgnify_link                //    string: Specifies the link to download mgnify
    pdb_mmcif_link             //    string: Specifies the link to download mmcif
    uniref90_link              //    string: Specifies the link to download uniref90
    pdb_seqres_link            //    string: Specifies the link to download pdb_seqres
    uniprot_link               //    string: Specifies the link to download uniprot
    rnacentral_active_seq_link //    string: Specifies the link to download rnacentral_active_seq
    nt_rna_2023_02_23_link     //    string: Specifies the link to download nt_rna_2023_02_23
    rfam_link                  //    string: Specifies the link to download rfam

    main:
    ch_versions   = channel.empty()

    if (alphafold3_db) {
        ch_params         = channel.value(file(alphafold3_params_path, checkIfExists: true))
        ch_small_bfd      = channel.value(file(small_bfd_path, checkIfExists: true))
        ch_mgnify         = channel.value(file(mgnify_path, checkIfExists: true))
        ch_mmcif          = channel.value(file(pdb_mmcif_path, checkIfExists: true))
        ch_uniref90       = channel.value(file(uniref90_path, checkIfExists: true))
        ch_pdb_seqres     = channel.value(file(pdb_seqres_path, checkIfExists: true))
        ch_uniprot        = channel.value(file(uniprot_path, checkIfExists: true))
        ch_rnacentral     = channel.value(file(rnacentral_active_seq_path, checkIfExists: true))
        ch_nt_rna         = channel.value(file(nt_rna_2023_02_23_path, checkIfExists: true))
        ch_rfam           = channel.value(file(rfam_path, checkIfExists: true))
    } else {

        ARIA2_SMALL_BFD (
            small_bfd_link
        )
        ch_small_bfd = ARIA2_SMALL_BFD.out.db
        ch_versions  = ch_versions.mix(ARIA2_SMALL_BFD.out.versions)

        ch_params = channel.value(file(alphafold3_params_path, checkIfExists: true))

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

        ARIA2_RNACENTRAL_ACTIVE_SEQ (
            rnacentral_active_seq_link
        )
        ch_rnacentral = ARIA2_RNACENTRAL_ACTIVE_SEQ.out.db
        ch_versions   = ch_versions.mix(ARIA2_RNACENTRAL_ACTIVE_SEQ.out.versions)

        ARIA2_NT_RNA_2023_02_23 (
            nt_rna_2023_02_23_link
        )
        ch_nt_rna = ARIA2_NT_RNA_2023_02_23.out.db
        ch_versions = ch_versions.mix(ARIA2_NT_RNA_2023_02_23.out.versions)

        ARIA2_RFAM (
            rfam_link
        )
        ch_rfam = ARIA2_RFAM.out.db
        ch_versions = ch_versions.mix(ARIA2_RFAM.out.versions)
    }

    emit:
    params     = ch_params
    small_bfd  = ch_small_bfd
    mgnify     = ch_mgnify
    pdb_mmcif  = ch_mmcif
    uniref90   = ch_uniref90
    pdb_seqres = ch_pdb_seqres
    uniprot    = ch_uniprot
    rnacentral = ch_rnacentral
    nt_rna     = ch_nt_rna
    rfam       = ch_rfam
    versions   = ch_versions
}
