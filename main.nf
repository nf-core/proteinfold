#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/proteinfold
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/proteinfold
    Website: https://nf-co.re/proteinfold
    Slack  : https://nfcore.slack.com/channels/proteinfold
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PREPARE_ALPHAFOLD2_DBS           } from './subworkflows/local/prepare_alphafold2_dbs'
include { PREPARE_ALPHAFOLD3_DBS           } from './subworkflows/local/prepare_alphafold3_dbs'
include { PREPARE_ESMFOLD_DBS              } from './subworkflows/local/prepare_esmfold_dbs'
include { PREPARE_ROSETTAFOLD_ALL_ATOM_DBS } from './subworkflows/local/prepare_rosettafold_all_atom_dbs'
include { PREPARE_HELIXFOLD3_DBS           } from './subworkflows/local/prepare_helixfold3_dbs'
include { PREPARE_BOLTZ_DBS                } from './subworkflows/local/prepare_boltz_dbs'
include { PREPARE_COLABFOLD_DBS            } from './subworkflows/local/prepare_colabfold_dbs'
include { PREPARE_ROSETTAFOLD2NA_DBS       } from './subworkflows/local/prepare_rosettafold2na_dbs'

include { ALPHAFOLD2                       } from './workflows/alphafold2'
include { ALPHAFOLD3                       } from './workflows/alphafold3'
include { COLABFOLD                        } from './workflows/colabfold'
include { ESMFOLD                          } from './workflows/esmfold'
include { ROSETTAFOLD_ALL_ATOM             } from './workflows/rosettafold_all_atom'
include { HELIXFOLD3                       } from './workflows/helixfold3'
include { BOLTZ                            } from './workflows/boltz'
include { ROSETTAFOLD2NA                   } from './workflows/rosettafold2na'

include { PIPELINE_INITIALISATION          } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { PIPELINE_COMPLETION              } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { getColabfoldAlphafold2Params     } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { getColabfoldAlphafold2ParamsPath } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { POST_PROCESSING                  } from './subworkflows/local/post_processing'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COLABFOLD PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params.colabfold_alphafold2_params_link = getColabfoldAlphafold2Params()
params.colabfold_alphafold2_params_path = getColabfoldAlphafold2ParamsPath()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline
//

workflow NFCORE_PROTEINFOLD {

    take:
    samplesheet  // channel: samplesheet read in from --input

    main:
    ch_samplesheet       = samplesheet
    ch_multiqc           = channel.empty()
    ch_versions          = channel.empty()
    ch_report_input      = channel.empty()
    ch_top_ranked_model  = channel.empty()
    requested_modes      = params.mode.toLowerCase().split(",")
    requested_modes_size = requested_modes.size()

    ch_dummy_file = channel.fromPath("$projectDir/assets/NO_FILE")
    ch_dummy_file_pae = channel.fromPath("$projectDir/assets/NO_FILE_PAE")

    //
    // WORKFLOW: Run alphafold2
    //
    if(requested_modes.contains("alphafold2")) {

        //
        // SUBWORKFLOW: Prepare Alphafold2 DBs
        //
        PREPARE_ALPHAFOLD2_DBS (
            params.alphafold2_db,
            params.alphafold2_full_dbs,
            params.alphafold2_bfd_path,
            params.alphafold2_small_bfd_path,
            params.alphafold2_params_path,
            params.alphafold2_mgnify_path,
            params.alphafold2_pdb70_path,
            params.alphafold2_pdb_mmcif_path,
            params.alphafold2_pdb_obsolete_path,
            params.alphafold2_uniref30_path,
            params.alphafold2_uniref90_path,
            params.alphafold2_pdb_seqres_path,
            params.alphafold2_uniprot_path,
            params.alphafold2_bfd_link,
            params.alphafold2_small_bfd_link,
            params.alphafold2_params_link,
            params.alphafold2_mgnify_link,
            params.alphafold2_pdb70_link,
            params.alphafold2_pdb_mmcif_link,
            params.alphafold2_pdb_obsolete_link,
            params.alphafold2_uniref30_link,
            params.alphafold2_uniref90_link,
            params.alphafold2_pdb_seqres_link,
            params.alphafold2_uniprot_sprot_link,
            params.alphafold2_uniprot_trembl_link
        )
        ch_versions = ch_versions.mix(PREPARE_ALPHAFOLD2_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/alphafold2 workflow
        //
        ALPHAFOLD2 (
            ch_samplesheet,
            ch_versions,
            params.alphafold2_full_dbs,
            params.alphafold2_mode,
            params.alphafold2_model_preset,
            params.uniref30_prefix,
            PREPARE_ALPHAFOLD2_DBS.out.params,
            PREPARE_ALPHAFOLD2_DBS.out.bfd,
            PREPARE_ALPHAFOLD2_DBS.out.small_bfd,
            PREPARE_ALPHAFOLD2_DBS.out.mgnify,
            PREPARE_ALPHAFOLD2_DBS.out.pdb70,
            PREPARE_ALPHAFOLD2_DBS.out.pdb_mmcif,
            PREPARE_ALPHAFOLD2_DBS.out.pdb_obsolete,
            PREPARE_ALPHAFOLD2_DBS.out.uniref30,
            PREPARE_ALPHAFOLD2_DBS.out.uniref90,
            PREPARE_ALPHAFOLD2_DBS.out.pdb_seqres,
            PREPARE_ALPHAFOLD2_DBS.out.uniprot
        )
        ch_multiqc          = ch_multiqc.mix(ALPHAFOLD2.out.multiqc_report.collect())
        ch_versions         = ch_versions.mix(ALPHAFOLD2.out.versions)
        ch_report_input     = ch_report_input
                                .mix(ALPHAFOLD2
                                .out
                                .pdb
                                .map { it ->
                                    [ it[0],
                                        it[1].sort { path ->
                                            def filename = path.name
                                            def matcher = filename =~ /ranked_(\d+)\.pdb/
                                            if (matcher.matches()) {
                                                return matcher[0][1].toInteger()
                                            } else {
                                                return 0  // fallback if no match
                                            }
                                        }.subList(0, Math.min(5, it[1].size() as int))
                                    ]
                                }
                                .join(ALPHAFOLD2.out.msa)
                                .join(ALPHAFOLD2.out.pae)
                            )

        ch_top_ranked_model = ch_top_ranked_model.mix(ALPHAFOLD2.out.top_ranked_pdb)
    }

    //
    // WORKFLOW: Run alphafold3
    //
    if(requested_modes.contains("alphafold3")) {

        //
        // SUBWORKFLOW: Prepare Alphafold3 DBs
        //
        PREPARE_ALPHAFOLD3_DBS (
            params.alphafold3_db,
            params.alphafold3_params_path,
            params.alphafold3_small_bfd_path,
            params.alphafold3_mgnify_path,
            params.alphafold3_pdb_mmcif_path,
            params.alphafold3_uniref90_path,
            params.alphafold3_pdb_seqres_path,
            params.alphafold3_uniprot_path,
            params.alphafold3_rnacentral_path,
            params.alphafold3_nt_rna_path,
            params.alphafold3_rfam_path,
            params.alphafold3_small_bfd_link,
            params.alphafold3_mgnify_link,
            params.alphafold3_pdb_mmcif_link,
            params.alphafold3_uniref90_link,
            params.alphafold3_pdb_seqres_link,
            params.alphafold3_uniprot_link,
            params.alphafold3_rnacentral_link,
            params.alphafold3_nt_rna_link,
            params.alphafold3_rfam_link
        )
        ch_versions = ch_versions.mix(PREPARE_ALPHAFOLD3_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/alphafold3 workflow
        //
        ALPHAFOLD3 (
            ch_samplesheet,
            ch_versions,
            PREPARE_ALPHAFOLD3_DBS.out.params,
            PREPARE_ALPHAFOLD3_DBS.out.small_bfd,
            PREPARE_ALPHAFOLD3_DBS.out.mgnify,
            PREPARE_ALPHAFOLD3_DBS.out.pdb_mmcif,
            PREPARE_ALPHAFOLD3_DBS.out.uniref90,
            PREPARE_ALPHAFOLD3_DBS.out.pdb_seqres,
            PREPARE_ALPHAFOLD3_DBS.out.uniprot
        )

        ch_multiqc      = ch_multiqc.mix(ALPHAFOLD3.out.multiqc_report)
        ch_versions     = ch_versions.mix(ALPHAFOLD3.out.versions)
        ch_report_input = ch_report_input
                            .mix(
                                ALPHAFOLD3
                                    .out
                                    .pdb
                                    .map { it ->
                                        [
                                            it[0],
                                            it[1].sort { path ->
                                                def filename = path.name
                                                def matcher = filename =~ /.*_ranked_(\d+)\.pdb/
                                                if (matcher.matches()) {
                                                    return matcher[0][1].toInteger()
                                                } else {
                                                    return 0  // fallback if no match
                                                }
                                            }.subList(0, Math.min(5, it[1].size() as int))
                                        ]
                                    }
                                .join(ALPHAFOLD3.out.msa)
                                .join(ALPHAFOLD3.out.pae)
                            )
        ch_top_ranked_model = ch_top_ranked_model.mix(ALPHAFOLD3.out.top_ranked_pdb)
    }

    //
    // WORKFLOW: Run colabfold
    //
    if(requested_modes.contains("colabfold")) {

        //
        // SUBWORKFLOW: Prepare Colabfold DBs
        //
        PREPARE_COLABFOLD_DBS (
            params.colabfold_db,
            params.use_msa_server,
            params.colabfold_alphafold2_params_path,
            params.colabfold_envdb_path,
            params.colabfold_envdb_path_padded,
            params.colabfold_uniref30_path,
            params.colabfold_uniref30_path_padded,
            params.colabfold_enable_gpu_search,
            params.colabfold_alphafold2_params_link,
            params.colabfold_db_link,
            params.colabfold_uniref30_link,
            params.colabfold_create_index
        )
        ch_versions = ch_versions.mix(PREPARE_COLABFOLD_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/colabfold workflow
        //
        if (params.colabfold_enable_gpu_search) {
            COLABFOLD (
                ch_samplesheet,
                ch_versions,
                params.colabfold_model_preset,
                PREPARE_COLABFOLD_DBS.out.params,
                PREPARE_COLABFOLD_DBS.out.colabfold_db_padded,
                PREPARE_COLABFOLD_DBS.out.uniref30_padded,
                params.colabfold_num_recycles
            )
        } else {
            COLABFOLD (
                ch_samplesheet,
                ch_versions,
                params.colabfold_model_preset,
                PREPARE_COLABFOLD_DBS.out.params,
                PREPARE_COLABFOLD_DBS.out.colabfold_db,
                PREPARE_COLABFOLD_DBS.out.uniref30,
                params.colabfold_num_recycles
            )
        }
        ch_multiqc          = ch_multiqc.mix(COLABFOLD.out.multiqc_report)
        ch_versions         = ch_versions.mix(COLABFOLD.out.versions)
        ch_report_input     = ch_report_input
                                .mix(COLABFOLD.out.pdb.map { it ->
                                    [ it[0],
                                        it[1].sort { path ->
                                            def filename = path.name
                                            def matcher = filename =~ /_relaxed_rank_(\d+)\.pdb/
                                            if (matcher.matches()) {
                                                return matcher[0][1].toInteger()
                                            } else {
                                                return 0  // fallback if no match
                                            }
                                        }.subList(0, Math.min(5, it[1].size() as int))
                                    ]
                                }
                                .join(COLABFOLD.out.msa)
                                .join(COLABFOLD.out.pae)
                            )

        ch_top_ranked_model = ch_top_ranked_model.mix(COLABFOLD.out.top_ranked_pdb)
    }

    //
    // WORKFLOW: Run esmfold
    //
    if(requested_modes.contains("esmfold")) {

        //
        // SUBWORKFLOW: Prepare esmfold DBs
        //
        PREPARE_ESMFOLD_DBS (
            params.esmfold_db,
            params.esmfold_params_path,
            params.esmfold_3B_v1,
            params.esm2_t36_3B_UR50D,
            params.esm2_t36_3B_UR50D_contact_regression
        )
        ch_versions = ch_versions.mix(PREPARE_ESMFOLD_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/esmfold workflow
        //
        ESMFOLD (
            ch_samplesheet,
            ch_versions,
            PREPARE_ESMFOLD_DBS.out.params,
            params.esmfold_num_recycles
        )

        ch_multiqc      = ch_multiqc.mix(ESMFOLD.out.multiqc_report.collect())
        ch_versions     = ch_versions.mix(ESMFOLD.out.versions)
        ch_report_input = ch_report_input.mix(
            ESMFOLD.out.pdb
                .combine(ch_dummy_file)
                .combine(ch_dummy_file_pae)
        )
        ch_top_ranked_model = ch_top_ranked_model.mix(ESMFOLD.out.pdb)
    }

    //

    // WORKFLOW: Run rosettafold_all_atom
    //
    if(requested_modes.contains("rosettafold_all_atom")) {

        //
        // SUBWORKFLOW: Prepare Rosettafold-all-atom DBs
        //
        PREPARE_ROSETTAFOLD_ALL_ATOM_DBS (
            params.rosettafold_all_atom_db,
            params.rosettafold_all_atom_bfd_path,
            params.rosettafold_all_atom_uniref30_path,
            params.rosettafold_all_atom_pdb100_path,
            params.rosettafold_all_atom_paper_weights_path,
            params.rosettafold_all_atom_bfd_link,
            params.rosettafold_all_atom_uniref30_link,
            params.rosettafold_all_atom_pdb100_link,
            params.rosettafold_all_atom_paper_weights_link
        )
        ch_versions = ch_versions.mix(PREPARE_ROSETTAFOLD_ALL_ATOM_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/rosettafold_all_atom workflow
        //
        ROSETTAFOLD_ALL_ATOM (
            ch_samplesheet,
            ch_versions,
            params.uniref30_prefix,
            PREPARE_ROSETTAFOLD_ALL_ATOM_DBS.out.bfd,
            PREPARE_ROSETTAFOLD_ALL_ATOM_DBS.out.uniref30,
            PREPARE_ROSETTAFOLD_ALL_ATOM_DBS.out.pdb100,
            PREPARE_ROSETTAFOLD_ALL_ATOM_DBS.out.rfaa_paper_weights
        )
        ch_multiqc                              = ch_multiqc.mix(ROSETTAFOLD_ALL_ATOM.out.multiqc_report.collect())
        ch_versions                             = ch_versions.mix(ROSETTAFOLD_ALL_ATOM.out.versions)
        ch_report_input                         = ch_report_input.mix(ROSETTAFOLD_ALL_ATOM.out.pdb
                                                                    .join(ROSETTAFOLD_ALL_ATOM.out.msa)
                                                                    .join(ROSETTAFOLD_ALL_ATOM.out.pae)
                                                                    )
        ch_top_ranked_model                     = ch_top_ranked_model.mix(ROSETTAFOLD_ALL_ATOM.out.pdb)
    }

    //
    // WORKFLOW: Run helixfold3
    //
    if(requested_modes.contains("helixfold3")) {

        //
        // SUBWORKFLOW: Prepare helixfold3 DBs
        //
        PREPARE_HELIXFOLD3_DBS (
            params.helixfold3_db,
            params.helixfold3_uniclust30_link,
            params.helixfold3_ccd_preprocessed_link,
            params.helixfold3_rfam_link,
            params.helixfold3_init_models_link,
            params.helixfold3_bfd_link,
            params.helixfold3_small_bfd_link,
            params.helixfold3_uniprot_sprot_link,
            params.helixfold3_uniprot_trembl_link,
            params.helixfold3_pdb_seqres_link,
            params.helixfold3_uniref90_link,
            params.helixfold3_mgnify_link,
            params.helixfold3_pdb_mmcif_link,
            params.helixfold3_obsolete_link,
            params.helixfold3_maxit_src_link,
            params.helixfold3_uniclust30_path,
            params.helixfold3_ccd_preprocessed_path,
            params.helixfold3_rfam_path,
            params.helixfold3_init_models_path,
            params.helixfold3_bfd_path,
            params.helixfold3_small_bfd_path,
            params.helixfold3_uniprot_path,
            params.helixfold3_pdb_seqres_path,
            params.helixfold3_uniref90_path,
            params.helixfold3_mgnify_path,
            params.helixfold3_pdb_mmcif_path,
            params.helixfold3_obsolete_path,
            params.helixfold3_maxit_src_path
        )
        ch_versions = ch_versions.mix(PREPARE_HELIXFOLD3_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/helixfold3 workflow
        //
        HELIXFOLD3 (
            ch_samplesheet,
            ch_versions,
            params.uniref30_prefix,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_uniclust30,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_ccd_preprocessed,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_rfam,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_bfd,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_small_bfd,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_uniprot,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_pdb_seqres,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_uniref90,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_mgnify,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_mmcif_files,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_obsolete,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_init_models,
            PREPARE_HELIXFOLD3_DBS.out.helixfold3_maxit_src
        )
        ch_multiqc          = ch_multiqc.mix(HELIXFOLD3.out.multiqc_report.collect())
        ch_versions         = ch_versions.mix(HELIXFOLD3.out.versions)
        ch_report_input     = ch_report_input
                                .mix(HELIXFOLD3.out.pdb.map { it ->
                                    [ it[0],
                                        it[1].sort { path ->
                                            def filename = path.name
                                            def matcher = filename =~ /ranked_(\d+)\.pdb/
                                            if (matcher.matches()) {
                                                return matcher[0][1].toInteger()
                                            } else {
                                                return 0  // fallback if no match
                                            }
                                        }.subList(0, Math.min(5, it[1].size() as int))
                                    ]
                                }
                                .join(HELIXFOLD3.out.msa)
                                .join(HELIXFOLD3.out.pae)
                            )
        ch_top_ranked_model = ch_top_ranked_model.mix(HELIXFOLD3.out.top_ranked_pdb)
    }

    //
    // WORKFLOW: Run rosettafold2na
    //
    if(requested_modes.contains("rosettafold2na")) {

        //
        // SUBWORKFLOW: Prepare RosettaFold2NA DBs
        //
        PREPARE_ROSETTAFOLD2NA_DBS (
            params.rosettafold2na_db,
            params.rosettafold2na_bfd_path,
            params.rosettafold2na_uniref30_path,
            params.rosettafold2na_pdb100_path,
            params.rosettafold2na_rna_path,
            params.rosettafold2na_weights_path,
            params.rosettafold2na_bfd_link,
            params.rosettafold2na_uniref30_link,
            params.rosettafold2na_pdb100_link,
            params.rosettafold2na_weights_link,
            params.rfam_full_region_link,
            params.rfam_cm_link,
            params.rnacentral_rfam_annotations_link,
            params.rnacentral_id_mapping_link,
            params.rnacentral_sequences_link
        )
        ch_versions = ch_versions.mix(PREPARE_ROSETTAFOLD2NA_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/rosettafold2na workflow
        //
        ROSETTAFOLD2NA (
            ch_samplesheet,
            ch_versions,
            PREPARE_ROSETTAFOLD2NA_DBS.out.bfd,
            PREPARE_ROSETTAFOLD2NA_DBS.out.uniref30,
            PREPARE_ROSETTAFOLD2NA_DBS.out.pdb100,
            PREPARE_ROSETTAFOLD2NA_DBS.out.rna,
            PREPARE_ROSETTAFOLD2NA_DBS.out.rosettafold2na_weights
        )
        ch_multiqc                              = ch_multiqc.mix(ROSETTAFOLD2NA.out.multiqc_report.collect())
        ch_versions                             = ch_versions.mix(ROSETTAFOLD2NA.out.versions)
        ch_report_input                         = ch_report_input
                                                    .mix(
                                                        ROSETTAFOLD2NA
                                                            .out
                                                            .pdb
                                                            .map { meta, pdb -> [ meta, [ pdb ] ] }
                                                            .join(ROSETTAFOLD2NA.out.msa)
                                                            .join(ROSETTAFOLD2NA.out.pae)
                                                    )
        ch_top_ranked_model                     = ch_top_ranked_model.mix(ROSETTAFOLD2NA.out.pdb)
    }

    // WORKFLOW: Run Boltz
    //
    if (params.mode.toLowerCase().split(",").contains("boltz")) {

        PREPARE_BOLTZ_DBS(
            params.boltz_db,
            params.boltz_ccd_path,
            params.boltz_model_path,
            params.boltz2_aff_path,
            params.boltz2_conf_path,
            params.boltz2_mols_path,
            params.boltz_ccd_link,
            params.boltz_model_link,
            params.boltz2_aff_link,
            params.boltz2_conf_link,
            params.boltz2_mols_link
        )
        ch_versions = ch_versions.mix(PREPARE_BOLTZ_DBS.out.versions)

        PREPARE_COLABFOLD_DBS (
            params.colabfold_db,
            params.use_msa_server,
            params.colabfold_alphafold2_params_path,
            params.colabfold_envdb_path,
            params.colabfold_uniref30_path,
            params.colabfold_alphafold2_params_link,
            params.colabfold_db_link,
            params.colabfold_uniref30_link,
            params.colabfold_create_index
        )
        ch_versions = ch_versions.mix(PREPARE_COLABFOLD_DBS.out.versions)

        BOLTZ(
            ch_samplesheet,
            ch_versions,
            PREPARE_BOLTZ_DBS.out.boltz_ccd,
            PREPARE_BOLTZ_DBS.out.boltz_model,
            PREPARE_BOLTZ_DBS.out.boltz2_aff,
            PREPARE_BOLTZ_DBS.out.boltz2_conf,
            PREPARE_BOLTZ_DBS.out.boltz2_mols,
            PREPARE_COLABFOLD_DBS.out.colabfold_db,
            PREPARE_COLABFOLD_DBS.out.uniref30,
            params.use_msa_server
        )
        ch_multiqc                  = ch_multiqc.mix(BOLTZ.out.multiqc_report)
        ch_versions                 = ch_versions.mix(BOLTZ.out.versions)
        ch_report_input             = ch_report_input.mix(
            BOLTZ.out.pdb
            .join(BOLTZ.out.msa)
            .join(BOLTZ.out.pae)
        )
        ch_top_ranked_model         = ch_top_ranked_model.mix(BOLTZ.out.top_ranked_pdb)
    }
    //
    // POST PROCESSING: generate visualisation reports
    //
    ch_multiqc_config        = channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true).first()
    ch_multiqc_custom_config = params.multiqc_config ? channel.fromPath( params.multiqc_config ).first()  : channel.empty()
    ch_multiqc_logo          = params.multiqc_logo   ? channel.fromPath( params.multiqc_logo ).first()    : channel.empty()
    ch_multiqc_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_report_template     = channel.value(file("$projectDir/assets/report_template.html", checkIfExists: true))
    ch_comparison_template = channel.value(file("$projectDir/assets/comparison_template.html", checkIfExists: true))

    POST_PROCESSING(
        params.skip_visualisation,
        requested_modes_size,
        ch_report_input,
        ch_report_template,
        ch_comparison_template,
        params.skip_foldseek,
        params.foldseek_db,
        params.foldseek_db_path,
        params.skip_multiqc,
        params.outdir,
        ch_versions,
        ch_multiqc,
        ch_multiqc_config,
        ch_multiqc_custom_config,
        ch_multiqc_logo,
        ch_multiqc_methods_description,
        ch_top_ranked_model
    )

    emit:
    multiqc_report = ch_multiqc
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_PROTEINFOLD (
        PIPELINE_INITIALISATION.out.samplesheet
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_PROTEINFOLD.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
