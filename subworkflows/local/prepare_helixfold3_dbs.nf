//
// Download all the required AlphaFold 2 databases and parameters
//

include {
    ARIA2_UNCOMPRESS as ARIA2_UNICLUST30
    ARIA2_UNCOMPRESS as ARIA2_CCD_PREPROCESSED
    ARIA2_UNCOMPRESS as ARIA2_RFAM
    ARIA2_UNCOMPRESS as ARIA2_BFD
    ARIA2_UNCOMPRESS as ARIA2_SMALL_BFD
    ARIA2_UNCOMPRESS as ARIA2_UNIPROT_SPROT
    ARIA2_UNCOMPRESS as ARIA2_UNIPROT_TREMBL
    ARIA2_UNCOMPRESS as ARIA2_OBSOLETE
    ARIA2_UNCOMPRESS as ARIA2_UNIREF90
    ARIA2_UNCOMPRESS as ARIA2_MGNIFY
    ARIA2_UNCOMPRESS as ARIA2_INIT_MODELS
} from './aria2_uncompress'

include { ARIA2 as ARIA2_PDB_SEQRES } from '../../modules/nf-core/aria2/main'
include { COMBINE_UNIPROT   } from '../../modules/local/combine_uniprot'
include { DOWNLOAD_PDBMMCIF } from '../../modules/local/download_pdbmmcif'

workflow PREPARE_HELIXFOLD3_DBS {

    take:
    helixfold3_db
    helixfold3_uniclust30_link
    helixfold3_ccd_preprocessed_link
    helixfold3_rfam_link
    helixfold3_init_models_link
    helixfold3_bfd_link
    helixfold3_small_bfd_link
    helixfold3_uniprot_sprot_link
    helixfold3_uniprot_trembl_link
    helixfold3_pdb_seqres_link
    helixfold3_uniref90_link
    helixfold3_mgnify_link
    helixfold3_pdb_mmcif_link
    helixfold3_obsolete_link
    helixfold3_uniclust30_path
    helixfold3_ccd_preprocessed_path
    helixfold3_rfam_path
    helixfold3_init_models_path
    helixfold3_bfd_path
    helixfold3_small_bfd_path
    helixfold3_uniprot_path
    helixfold3_pdb_seqres_path
    helixfold3_uniref90_path
    helixfold3_mgnify_path
    helixfold3_pdb_mmcif_path
    helixfold3_obsolete_path
    helixfold3_maxit_src_path

    main:
    ch_helixfold3_maxit_src             = Channel.value(file(helixfold3_maxit_src_path))
    ch_versions                         = Channel.empty()

    if (helixfold3_db) {
        ch_helixfold3_uniclust30        = Channel.value(file(helixfold3_uniclust30_path))
        ch_helixfold3_ccd_preprocessed  = Channel.value(file(helixfold3_ccd_preprocessed_path))
        ch_helixfold3_rfam              = Channel.value(file(helixfold3_rfam_path))
        ch_helixfold3_bfd               = Channel.value(file(helixfold3_bfd_path))
        ch_helixfold3_small_bfd         = Channel.value(file(helixfold3_small_bfd_path))
        ch_helixfold3_uniprot           = Channel.value(file(helixfold3_uniprot_path))
        ch_helixfold3_pdb_seqres        = Channel.value(file(helixfold3_pdb_seqres_path))
        ch_helixfold3_uniref90          = Channel.value(file(helixfold3_uniref90_path))
        ch_helixfold3_mgnify            = Channel.value(file(helixfold3_mgnify_path))
        ch_helixfold3_mmcif_files       = Channel.value(file(helixfold3_pdb_mmcif_path))
        ch_helixfold3_obsolete          = Channel.value(file(helixfold3_obsolete_path))
        ch_helixfold3_init_models       = Channel.value(file(helixfold3_init_models_path))
    }
    else {
        ARIA2_UNICLUST30(helixfold3_uniclust30_link)
        ch_helixfold3_uniclust30 = ARIA2_UNICLUST30.out.db
        ch_versions = ch_versions.mix(ARIA2_UNICLUST30.out.versions)

        ARIA2_CCD_PREPROCESSED(helixfold3_ccd_preprocessed_link)
        ch_helixfold3_ccd_preprocessed = ARIA2_CCD_PREPROCESSED.out.db
        ch_versions = ch_versions.mix(ARIA2_CCD_PREPROCESSED.out.versions)

        ARIA2_RFAM(helixfold3_rfam_link)
        ch_helixfold3_rfam = ARIA2_RFAM.out.db
        ch_versions = ch_versions.mix(ARIA2_RFAM.out.versions)

        ARIA2_BFD(helixfold3_bfd_link)
        ch_helixfold3_bfd = ARIA2_BFD.out.db
        ch_versions = ch_versions.mix(ARIA2_BFD.out.versions)

        ARIA2_SMALL_BFD(helixfold3_small_bfd_link)
        ch_helixfold3_small_bfd = ARIA2_SMALL_BFD.out.db
        ch_versions = ch_versions.mix(ARIA2_SMALL_BFD.out.versions)

        ARIA2_UNIREF90(helixfold3_uniref90_link)
        ch_helixfold3_uniref90 = ARIA2_UNIREF90.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF90.out.versions)

        ARIA2_MGNIFY(helixfold3_mgnify_link)
        ch_helixfold3_mgnify = ARIA2_MGNIFY.out.db
        ch_versions = ch_versions.mix(ARIA2_MGNIFY.out.versions)

        DOWNLOAD_PDBMMCIF(
            helixfold3_pdb_mmcif_link
            )
        ch_helixfold3_mmcif_files = DOWNLOAD_PDBMMCIF.out.ch_db
        ch_versions               = ch_versions.mix(DOWNLOAD_PDBMMCIF.out.versions)

        ARIA2_OBSOLETE(
            helixfold3_obsolete_link
        )
        ch_helixfold3_obsolete = ARIA2_OBSOLETE.out.db
        ch_versions            = ch_versions.mix(ARIA2_OBSOLETE.out.versions)

        ARIA2_INIT_MODELS(helixfold3_init_models_link)
        ch_helixfold3_init_models = ARIA2_INIT_MODELS.out.db
        ch_versions               = ch_versions.mix(ARIA2_INIT_MODELS.out.versions)

        ARIA2_PDB_SEQRES (
            [
                [:],
                helixfold3_pdb_seqres_link
            ]
        )
        ch_helixfold3_pdb_seqres = ARIA2_PDB_SEQRES.out.downloaded_file.map{ it[1] }
        ch_versions = ch_versions.mix(ARIA2_PDB_SEQRES.out.versions)


        ARIA2_UNIPROT_SPROT(
            helixfold3_uniprot_sprot_link
        )
        ch_versions = ch_versions.mix(ARIA2_UNIPROT_SPROT.out.versions)
        ARIA2_UNIPROT_TREMBL(
            helixfold3_uniprot_trembl_link
        )
        ch_versions = ch_versions.mix(ARIA2_UNIPROT_TREMBL.out.versions)
        COMBINE_UNIPROT (
            ARIA2_UNIPROT_SPROT.out.db,
            ARIA2_UNIPROT_TREMBL.out.db
        )
        ch_helixfold3_uniprot = COMBINE_UNIPROT.out.ch_db
        ch_version =  ch_versions.mix(COMBINE_UNIPROT.out.versions)
    }

    emit:
    helixfold3_uniclust30       = ch_helixfold3_uniclust30
    helixfold3_ccd_preprocessed = ch_helixfold3_ccd_preprocessed
    helixfold3_rfam             = ch_helixfold3_rfam
    helixfold3_bfd              = ch_helixfold3_bfd
    helixfold3_small_bfd        = ch_helixfold3_small_bfd
    helixfold3_uniprot          = ch_helixfold3_uniprot
    helixfold3_pdb_seqres       = ch_helixfold3_pdb_seqres
    helixfold3_uniref90         = ch_helixfold3_uniref90
    helixfold3_mgnify           = ch_helixfold3_mgnify
    helixfold3_mmcif_files      = ch_helixfold3_mmcif_files
    helixfold3_obsolete         = ch_helixfold3_obsolete
    helixfold3_init_models      = ch_helixfold3_init_models
    helixfold3_maxit_src        = ch_helixfold3_maxit_src
    versions                    = ch_versions
}
