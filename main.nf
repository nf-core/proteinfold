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
include { PREPARE_BOLTZ_DBS                } from './subworkflows/local/prepare_boltz_dbs'

include { PREPARE_COLABFOLD_DBS  as PREPARE_COLABFOLD_DBS_COLABFOLD  } from './subworkflows/local/prepare_colabfold_dbs'
include { PREPARE_COLABFOLD_DBS  as PREPARE_COLABFOLD_DBS_BOLTZ      } from './subworkflows/local/prepare_colabfold_dbs'
include { PREPARE_COLABFOLD_DBS  as PREPARE_COLABFOLD_DBS_COLABFOLD2 } from './subworkflows/local/prepare_colabfold_dbs'
include { PREPARE_COLABFOLD2_DBS               } from './subworkflows/local/prepare_colabfold2_dbs'

include { ALPHAFOLD2                       } from './workflows/alphafold2'
include { ALPHAFOLD3                       } from './workflows/alphafold3'
include { COLABFOLD                        } from './workflows/colabfold'
include { COLABFOLD2                       } from './workflows/colabfold2'
include { ESMFOLD                          } from './workflows/esmfold'
include { BOLTZ                            } from './workflows/boltz'

include { PIPELINE_INITIALISATION          } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { PIPELINE_COMPLETION              } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { POST_PROCESSING                  } from './subworkflows/local/post_processing'

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
    ch_report_input      = channel.empty()
    ch_top_ranked_model  = channel.empty()
    requested_modes      = params.mode.toLowerCase().split(",")
    requested_modes_size = requested_modes.size()

    if (requested_modes.contains("colabfold") && params.colabfold_use_templates && !params.use_msa_server) {
        error("`--colabfold_use_templates` requires `--use_msa_server` in ColabFold mode.")
    }

    // Backends are named after the tool each one runs; alphafold3 and boltz2 need the colabfold2- prefix to avoid clashing with existing modes.
    colabfold2_prefixed_models = [ 'alphafold3', 'boltz2' ]
    colabfold2_bare_models     = [
        'openfold3', 'openbind0', 'protenix2', 'chai1', 'intellifold2', 'opendde',
        'rosettafold3', 'esmfold2'
    ]
    colabfold2_mode_tokens = ( colabfold2_prefixed_models.collect { "colabfold2-${it}".toString() } + colabfold2_bare_models )
    // Trim every token before matching so that whitespace around commas in
    // `--mode a,b` cannot leak into backend parsing; clean input is unaffected.
    colabfold2_submodes = requested_modes
        .collect { mode -> mode.trim() }
        .findAll { mode -> colabfold2_mode_tokens.contains(mode) }
    if (requested_modes.collect { it.trim() }.contains('colabfold2')) {
        error("The bare `colabfold2` mode selects no backend. Name one, e.g. `--mode colabfold2-alphafold3`, or one of: ${colabfold2_bare_models.join(', ')}.")
    }
    // Fail lookalike tokens (retired spellings, mistyped backends) here rather than silently running nothing.
    colabfold2_lookalikes = requested_modes
        .collect { mode -> mode.trim() }
        .findAll { mode -> mode.startsWith('colabfold2') || mode.startsWith('colabfold-') }
    colabfold2_unknown_submodes = requested_modes
        .collect { mode -> mode.trim() }
        .findAll { mode ->
            mode != 'colabfold2' &&
            !colabfold2_submodes.contains(mode) &&
            ( colabfold2_lookalikes.contains(mode) || ( colabfold2_bare_models + colabfold2_prefixed_models ).any { backend -> mode.startsWith(backend) && mode != backend } )
        }
    if (colabfold2_unknown_submodes) {
        error("Unknown ColabFold2 mode(s): ${colabfold2_unknown_submodes.join(', ')}. Supported modes: ${colabfold2_mode_tokens.join(', ')}.")
    }
    if (colabfold2_submodes.size() > 1) {
        error("Running multiple ColabFold2 backends in one invocation is not supported yet; run them separately.")
    }
    // The public mode token is also the output namespace; esmfold2 selects its model separately.
    colabfold2_public_mode = colabfold2_submodes ? colabfold2_submodes[0] : null
    colabfold2_esmfold2_models = [
        'msa'    : [ model_type: 'esmfold2',        use_esm: false ],
        'lm300m' : [ model_type: 'esmfold2_lm300m', use_esm: true  ],
        'lm600m' : [ model_type: 'esmfold2_lm600m', use_esm: true  ]
    ]
    colabfold2_esmfold2_selection = params.esmfold2_model ?: 'msa'
    if (colabfold2_public_mode == 'colabfold2-alphafold3' && params.colabfold2_weights_precision == 'int8') {
        error("ColabFold2 official alphafold3 supports fp32 weights only; --colabfold2_weights_precision int8 cannot be used with --mode colabfold2-alphafold3.")
    }
    if (colabfold2_public_mode == 'esmfold2') {
        def esmfold2_model = colabfold2_esmfold2_models[colabfold2_esmfold2_selection]
        if (esmfold2_model == null) {
            error("Unsupported --esmfold2_model '${colabfold2_esmfold2_selection}'. Choose one of: ${colabfold2_esmfold2_models.keySet().join(', ')}.")
        }
        colabfold2_model_for_submode = esmfold2_model.model_type
        colabfold2_use_esm = esmfold2_model.use_esm
    } else {
        // Prefixed tokens carry the upstream name after the prefix; bare tokens are already upstream names.
        colabfold2_model_for_submode = colabfold2_public_mode ?
            colabfold2_public_mode.replaceFirst(/^colabfold2-/, '') : null
        colabfold2_use_esm = false
    }
    // Only assert when a ColabFold2 backend was actually requested; the resolution above yields null otherwise.
    if (colabfold2_submodes && !(colabfold2_model_for_submode in ( colabfold2_prefixed_models + colabfold2_bare_models + [ 'esmfold2_lm300m', 'esmfold2_lm600m' ] ))) {
        error("ColabFold2 mode '${colabfold2_submodes[0]}' resolved to backend '${colabfold2_model_for_submode}', which is not a supported AlphaFold3-family backend. Supported modes: ${colabfold2_mode_tokens.join(', ')}.")
    }

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

        //
        // WORKFLOW: Run nf-core/alphafold2 workflow
        //
        ALPHAFOLD2 (
            ch_samplesheet,
            params.alphafold2_full_dbs,
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
        ch_multiqc          = ch_multiqc.mix(ALPHAFOLD2.out.multiqc_metrics)
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
                                .join(ALPHAFOLD2.out.iptm)
                                .join(ALPHAFOLD2.out.ipsae)
                                .join(ALPHAFOLD2.out.chainwise_iptm)
                                .join(ALPHAFOLD2.out.chainwise_ipsae)
                            )

        ch_top_ranked_model = ch_top_ranked_model.mix(ALPHAFOLD2.out.top_ranked_pdb)
    }

    //
    // WORKFLOW: Run alphafold3 (data pipeline + inference as separate steps)
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

        //
        // WORKFLOW: Run nf-core/alphafold3 workflow
        //
        ALPHAFOLD3 (
            ch_samplesheet,
            channel.empty(),
            PREPARE_ALPHAFOLD3_DBS.out.params,
            PREPARE_ALPHAFOLD3_DBS.out.small_bfd,
            PREPARE_ALPHAFOLD3_DBS.out.mgnify,
            PREPARE_ALPHAFOLD3_DBS.out.pdb_mmcif,
            PREPARE_ALPHAFOLD3_DBS.out.uniref90,
            PREPARE_ALPHAFOLD3_DBS.out.pdb_seqres,
            PREPARE_ALPHAFOLD3_DBS.out.uniprot,
            PREPARE_ALPHAFOLD3_DBS.out.nt_rna,
            PREPARE_ALPHAFOLD3_DBS.out.rfam,
            PREPARE_ALPHAFOLD3_DBS.out.rnacentral
        )

        ch_multiqc      = ch_multiqc.mix(ALPHAFOLD3.out.multiqc_metrics)
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
                                                def matcher = filename =~ /.*_ranked_(\d+)\.(?:pdb|cif|mmcif)/
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
                                .join(ALPHAFOLD3.out.iptm)
                                .join(ALPHAFOLD3.out.ipsae)
                                .join(ALPHAFOLD3.out.chainwise_iptm)
                                .join(ALPHAFOLD3.out.chainwise_ipsae)
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
        PREPARE_COLABFOLD_DBS_COLABFOLD (
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

        //
        // WORKFLOW: Run nf-core/colabfold workflow
        //
        COLABFOLD (
            ch_samplesheet,
            PREPARE_COLABFOLD_DBS_COLABFOLD.out.params,
            PREPARE_COLABFOLD_DBS_COLABFOLD.out.colabfold_db,
            PREPARE_COLABFOLD_DBS_COLABFOLD.out.uniref30,
            params.colabfold_num_recycles
        )

        ch_multiqc          = ch_multiqc.mix(COLABFOLD.out.multiqc_metrics)
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
                                .join(COLABFOLD.out.iptm)
                                .join(COLABFOLD.out.ipsae)
                                .join(COLABFOLD.out.chainwise_iptm)
                                .join(COLABFOLD.out.chainwise_ipsae)
                            )

        ch_top_ranked_model = ch_top_ranked_model.mix(COLABFOLD.out.top_ranked_pdb)
    }

    //
    // WORKFLOW: Run the experimental ColabFold2 multi-model preview
    //
    if(!colabfold2_submodes.isEmpty()) {
        if (!params.colabfold2_params_path || (!params.colabfold_db && !params.use_msa_server)) {
            error("ColabFold2 needs a weights root: set --db/--colabfold_db (weights are then read from <colabfold_db>/colabfold2_models) or point --colabfold2_params_path at the weights directory directly. Offline runs additionally require --colabfold_db for the MMseqs2 search; the --use_msa_server leg needs only the weights root.")
        }
        PREPARE_COLABFOLD2_DBS (
            params.colabfold2_params_path,
            colabfold2_model_for_submode,
            params.colabfold2_weights_precision
        )
        ch_colabfold2_params_path = PREPARE_COLABFOLD2_DBS.out.params_path

        // The consented remote-MSA leg never consumes the ColabFold search databases, so skip
        // database preparation: its download path would fetch AF2 parameters colabfold2 never reads.
        ch_colabfold2_db       = channel.empty()
        ch_colabfold2_uniref30 = channel.empty()
        if (!params.use_msa_server) {
            //
            // SUBWORKFLOW: Prepare Colabfold DBs
            //
            PREPARE_COLABFOLD_DBS_COLABFOLD2 (
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
            ch_colabfold2_db       = PREPARE_COLABFOLD_DBS_COLABFOLD2.out.colabfold_db
            ch_colabfold2_uniref30 = PREPARE_COLABFOLD_DBS_COLABFOLD2.out.uniref30
        }

        // PREPARE_COLABFOLD_DBS_COLABFOLD2.out.params carries AF2 parameters that colabfold2 never reads.
        COLABFOLD2(
            ch_samplesheet,
            ch_colabfold2_params_path,
            colabfold2_model_for_submode,
            colabfold2_use_esm,
            colabfold2_public_mode,
            params.colabfold_num_recycles,
            ch_colabfold2_db,
            ch_colabfold2_uniref30
        )

        ch_multiqc      = ch_multiqc.mix(COLABFOLD2.out.multiqc_metrics)
        ch_report_input = ch_report_input.mix(
            COLABFOLD2.out.pdb
                .join(COLABFOLD2.out.msa)
                .join(COLABFOLD2.out.pae)
                .join(COLABFOLD2.out.iptm)
                .join(COLABFOLD2.out.ipsae)
                .join(COLABFOLD2.out.chainwise_iptm)
                .join(COLABFOLD2.out.chainwise_ipsae)
        )
        ch_top_ranked_model = ch_top_ranked_model.mix(COLABFOLD2.out.top_ranked_pdb)
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

        //
        // WORKFLOW: Run nf-core/esmfold workflow
        //
        ESMFOLD (
            ch_samplesheet,
            PREPARE_ESMFOLD_DBS.out.params,
            params.esmfold_num_recycles
        )

        ch_multiqc      = ch_multiqc.mix(ESMFOLD.out.multiqc_metrics)
        ch_report_input = ch_report_input.mix(
            ESMFOLD.out.pdb
                .combine(ch_dummy_file)
                .combine(ch_dummy_file_pae)
                .combine(ch_dummy_file)
                .combine(ch_dummy_file)
                .combine(ch_dummy_file)
                .combine(ch_dummy_file)
        )
        ch_top_ranked_model = ch_top_ranked_model.mix(ESMFOLD.out.pdb)
    }

    // WORKFLOW: Run Boltz
    //
    if (requested_modes.contains("boltz")) {

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

        PREPARE_COLABFOLD_DBS_BOLTZ (
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

        BOLTZ(
            ch_samplesheet,
            PREPARE_BOLTZ_DBS.out.boltz_ccd,
            PREPARE_BOLTZ_DBS.out.boltz_model,
            PREPARE_BOLTZ_DBS.out.boltz2_aff,
            PREPARE_BOLTZ_DBS.out.boltz2_conf,
            PREPARE_BOLTZ_DBS.out.boltz2_mols,
            PREPARE_COLABFOLD_DBS_BOLTZ.out.colabfold_db,
            PREPARE_COLABFOLD_DBS_BOLTZ.out.uniref30,
            params.use_msa_server
        )
        ch_multiqc                  = ch_multiqc.mix(BOLTZ.out.multiqc_metrics)
        ch_report_input             = ch_report_input.mix(
            BOLTZ.out.pdb
            .join(BOLTZ.out.msa)
            .join(BOLTZ.out.pae)
            .join(BOLTZ.out.iptm)
            .join(BOLTZ.out.ipsae)
            .join(BOLTZ.out.chainwise_iptm)
            .join(BOLTZ.out.chainwise_ipsae)
        )
        ch_top_ranked_model         = ch_top_ranked_model.mix(BOLTZ.out.top_ranked_pdb)
    }
    //
    // POST PROCESSING: generate visualisation reports
    //
    ch_multiqc_config        = channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true).first()
    ch_multiqc_custom_config = params.multiqc_config ? channel.fromPath( params.multiqc_config, checkIfExists: true ).first()  : channel.empty()
    ch_multiqc_logo          = params.multiqc_logo   ? channel.fromPath( params.multiqc_logo ).first()    : channel.empty()
    ch_multiqc_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_report_template     = channel.value(file("$projectDir/assets/report_template.html", checkIfExists: true))
    ch_comparison_template = channel.value(file("$projectDir/assets/comparison_template.html", checkIfExists: true))

    // Inject msa_tool into meta based on selected model for report provenance.
    def msaToolMap = [
        alphafold2:           'jackhmmer',
        alphafold3:           'jackhmmer',
        colabfold:            'mmseqs2',
        colabfold2:           'mmseqs2',
        boltz:                'mmseqs2',
        esmfold:              'None',
    ]
    ch_report_input = ch_report_input.map { tupleData ->
        def meta = tupleData[0]
        def m = meta.clone()
        m.msa_tool = msaToolMap.get(meta.model, 'None')
        [m] + tupleData.drop(1)
    }

    def ch_software_versions = channel.topic('versions')
        .unique()
        .map { process_name, tool_name, version ->
            "\"${process_name}:${tool_name}\": ${version}"
        }
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_proteinfold_software_mqc_versions.yml',
            newLine: true,
            sort: true
        )

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
        ch_multiqc,
        ch_multiqc_config,
        ch_multiqc_custom_config,
        params.multiqc_logo,
        ch_multiqc_methods_description,
        ch_software_versions,
        ch_top_ranked_model
    )

    emit:
    multiqc_report = POST_PROCESSING.out.multiqc_report
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
        NFCORE_PROTEINFOLD.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
