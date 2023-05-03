//
// Download all the required AlphaFold 2 databases and parameters
//

include {
    ARIA2_UNCOMPRESS as ARIA2_ALPHAFOLD2_PARAMS
    ARIA2_UNCOMPRESS as ARIA2_BFD
    ARIA2_UNCOMPRESS as ARIA2_SMALL_BFD
    ARIA2_UNCOMPRESS as ARIA2_MGNIFY
    ARIA2_UNCOMPRESS as ARIA2_PDB70
    ARIA2_UNCOMPRESS as ARIA2_UNICLUST30
    ARIA2_UNCOMPRESS as ARIA2_UNIREF90
    ARIA2_UNCOMPRESS as ARIA2_UNIPROT_SPROT
    ARIA2_UNCOMPRESS as ARIA2_UNIPROT_TREMBL } from './aria2_uncompress'

include { ARIA2             } from '../../modules/nf-core/aria2/main'
include { COMBINE_UNIPROT   } from '../../modules/local/combine_uniprot'
include { DOWNLOAD_PDBMMCIF } from '../../modules/local/download_pdbmmcif'

workflow PREPARE_ALPHAFOLD2_DBS {
    main:
    ch_bfd        = Channel.empty()
    ch_small_bfd  = Channel.empty()
    ch_versions   = Channel.empty()


    if (params.alphafold2_db) {
        if (params.full_dbs) {
            ch_bfd       = file( params.bfd_path )
            ch_small_bfd = file( "${projectDir}/assets/dummy_db" )
        }
        else {
            ch_bfd       = file( "${projectDir}/assets/dummy_db" )
            ch_small_bfd = file( params.small_bfd_path )
        }

        ch_params     = file( params.alphafold2_params_path )
        ch_mgnify     = file( params.mgnify_path )
        ch_pdb70      = file( params.pdb70_path, type: 'dir' )
        ch_mmcif_files = file( params.pdb_mmcif_path, type: 'dir' )
        ch_mmcif_obsolete = file( params.pdb_mmcif_path, type: 'file' )
        ch_mmcif = ch_mmcif_files + ch_mmcif_obsolete
        ch_uniref30   = file( params.uniref30_alphafold2_path, type: 'any' )
        ch_uniref90   = file( params.uniref90_path )
        ch_pdb_seqres = file( params.pdb_seqres_path )
        ch_uniprot    = file( params.uniprot_path )
    }
    else {
        if (params.full_dbs) {
            ARIA2_BFD(
                params.bfd
            )
            ch_bfd =  ARIA2_BFD.out.db
            ch_versions = ch_versions.mix(ARIA2_BFD.out.versions)
        } else {
            ARIA2_SMALL_BFD(
                params.small_bfd
            )
            ch_small_bfd = ARIA2_SMALL_BFD.out.db
            ch_versions = ch_versions.mix(ARIA2_SMALL_BFD.out.versions)
        }

        ARIA2_ALPHAFOLD2_PARAMS(
            params.alphafold2_params
        )
        ch_params = ARIA2_ALPHAFOLD2_PARAMS.out.db
        ch_versions = ch_versions.mix(ARIA2_ALPHAFOLD2_PARAMS.out.versions)

        ARIA2_MGNIFY(
            params.mgnify
        )
        ch_mgnify = ARIA2_MGNIFY.out.db
        ch_versions = ch_versions.mix(ARIA2_MGNIFY.out.versions)


        ARIA2_PDB70(
            params.pdb70
        )
        ch_pdb70 = ARIA2_PDB70.out.db
        ch_versions = ch_versions.mix(ARIA2_PDB70.out.versions)

        DOWNLOAD_PDBMMCIF(
            params.pdb_mmcif,
            params.pdb_obsolete
        )
        ch_mmcif = DOWNLOAD_PDBMMCIF.out.ch_db
        ch_versions = ch_versions.mix(DOWNLOAD_PDBMMCIF.out.versions)

        ARIA2_UNIREF30(
            params.uniref30
        )
        ch_uniref30 = ARIA2_UNICLUST30.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIref30.out.versions)

        ARIA2_UNIREF90(
            params.uniref90
        )
        ch_uniref90 = ARIA2_UNIREF90.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF90.out.versions)

        ARIA2 (
            params.pdb_seqres
        )
        ch_pdb_seqres = ARIA2.out.downloaded_file
        ch_versions = ch_versions.mix(ARIA2.out.versions)

        ARIA2_UNIPROT_SPROT(
            params.uniprot_sprot
        )
        ch_versions = ch_versions.mix(ARIA2_UNIPROT_SPROT.out.versions)
        ARIA2_UNIPROT_TREMBL(
            params.uniprot_trembl
        )
        ch_versions = ch_versions.mix(ARIA2_UNIPROT_TREMBL.out.versions)
        COMBINE_UNIPROT (
            ARIA2_UNIPROT_SPROT.out.db,
            ARIA2_UNIPROT_TREMBL.out.db
        )
        ch_uniprot = COMBINE_UNIPROT.out.ch_db
        ch_version =  ch_versions.mix(COMBINE_UNIPROT.out.versions)
    }

	emit:
    bfd        = ch_bfd
    small_bfd  = ch_small_bfd
    params     = ch_params
    mgnify     = ch_mgnify
    pdb70      = ch_pdb70
    pdb_mmcif  = ch_mmcif
    uniref30   = ch_uniref30
    uniref90   = ch_uniref90
    pdb_seqres = ch_pdb_seqres
    uniprot    = ch_uniprot
    versions   = ch_versions
}
