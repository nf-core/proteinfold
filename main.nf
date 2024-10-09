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

if (params.mode.toLowerCase().split(",").contains("alphafold2")) {
    include { PREPARE_ALPHAFOLD2_DBS } from './subworkflows/local/prepare_alphafold2_dbs'
    include { ALPHAFOLD2             } from './workflows/alphafold2'
}
if (params.mode.toLowerCase().split(",").contains("colabfold")) {
    include { PREPARE_COLABFOLD_DBS } from './subworkflows/local/prepare_colabfold_dbs'
    include { COLABFOLD             } from './workflows/colabfold'
}
if (params.mode.toLowerCase().split(",").contains("esmfold")) {
    include { PREPARE_ESMFOLD_DBS } from './subworkflows/local/prepare_esmfold_dbs'
    include { ESMFOLD             } from './workflows/esmfold'
}

include { PIPELINE_INITIALISATION          } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { PIPELINE_COMPLETION              } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { getColabfoldAlphafold2Params     } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { getColabfoldAlphafold2ParamsPath } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'

include { GENERATE_REPORT     } from './modules/local/generate_report'
include { FOLDSEEK_EASYSEARCH } from './modules/nf-core/foldseek/easysearch/main'

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
    samplesheet // channel: samplesheet read in from --input

    main:
    ch_samplesheet  = samplesheet
    ch_multiqc      = Channel.empty()
    ch_versions     = Channel.empty()
    ch_report_input = Channel.empty()

    //
    // WORKFLOW: Run alphafold2
    //
    if(params.mode.toLowerCase().split(",").contains("alphafold2")) {
        //
        // SUBWORKFLOW: Prepare Alphafold2 DBs
        //
        PREPARE_ALPHAFOLD2_DBS (
            params.alphafold2_db,
            params.full_dbs,
            params.bfd_path,
            params.small_bfd_path,
            params.alphafold2_params_path,
            params.mgnify_path,
            params.pdb70_path,
            params.pdb_mmcif_path,
            params.uniref30_alphafold2_path,
            params.uniref90_path,
            params.pdb_seqres_path,
            params.uniprot_path,
            params.bfd_link,
            params.small_bfd_link,
            params.alphafold2_params_link,
            params.mgnify_link,
            params.pdb70_link,
            params.pdb_mmcif_link,
            params.pdb_obsolete_link,
            params.uniref30_alphafold2_link,
            params.uniref90_link,
            params.pdb_seqres_link,
            params.uniprot_sprot_link,
            params.uniprot_trembl_link
        )
        ch_versions = ch_versions.mix(PREPARE_ALPHAFOLD2_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/alphafold2 workflow
        //
        ALPHAFOLD2 (
            ch_samplesheet,
            ch_versions,
            params.full_dbs,
            params.alphafold2_mode,
            params.alphafold2_model_preset,
            PREPARE_ALPHAFOLD2_DBS.out.params,
            PREPARE_ALPHAFOLD2_DBS.out.bfd.ifEmpty([]).first(),
            PREPARE_ALPHAFOLD2_DBS.out.small_bfd.ifEmpty([]).first(),
            PREPARE_ALPHAFOLD2_DBS.out.mgnify,
            PREPARE_ALPHAFOLD2_DBS.out.pdb70,
            PREPARE_ALPHAFOLD2_DBS.out.pdb_mmcif,
            PREPARE_ALPHAFOLD2_DBS.out.uniref30,
            PREPARE_ALPHAFOLD2_DBS.out.uniref90,
            PREPARE_ALPHAFOLD2_DBS.out.pdb_seqres,
            PREPARE_ALPHAFOLD2_DBS.out.uniprot
        )
        ch_multiqc  = ALPHAFOLD2.out.multiqc_report
        ch_versions = ch_versions.mix(ALPHAFOLD2.out.versions)
        ch_report_input = ch_report_input.mix(
            ALPHAFOLD2.out.pdb.join(ALPHAFOLD2.out.msa).map{it[0]["model"] = "alphafold2"; it}
        )
    }

    //
    // WORKFLOW: Run colabfold
    //
    if(params.mode.toLowerCase().split(",").contains("colabfold")) {
        //
        // SUBWORKFLOW: Prepare Colabfold DBs
        //
        PREPARE_COLABFOLD_DBS (
            params.colabfold_db,
            params.colabfold_server,
            params.colabfold_alphafold2_params_path,
            params.colabfold_db_path,
            params.uniref30_colabfold_path,
            params.colabfold_alphafold2_params_link,
            params.colabfold_db_link,
            params.uniref30_colabfold_link,
            params.create_colabfold_index
        )
        ch_versions = ch_versions.mix(PREPARE_COLABFOLD_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/colabfold workflow
        //
        COLABFOLD (
            ch_samplesheet,
            ch_versions,
            params.colabfold_model_preset,
            PREPARE_COLABFOLD_DBS.out.params,
            PREPARE_COLABFOLD_DBS.out.colabfold_db,
            PREPARE_COLABFOLD_DBS.out.uniref30,
            params.num_recycles_colabfold
        )
        ch_multiqc  = COLABFOLD.out.multiqc_report
        ch_versions = ch_versions.mix(COLABFOLD.out.versions)
        ch_report_input = ch_report_input.mix(
            COLABFOLD
                .out
                .pdb
                .join(COLABFOLD.out.msa)
                .map { it[0]["model"] = "colabfold"; it }
        )
    }

    //
    // WORKFLOW: Run esmfold
    //
    if(params.mode.toLowerCase().split(",").contains("esmfold")) {
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
            params.num_recycles_esmfold
        )
        ch_multiqc  = ESMFOLD.out.multiqc_report
        ch_versions = ch_versions.mix(ESMFOLD.out.versions)
        ch_report_input = ch_report_input.mix(
            ESMFOLD.out.pdb.combine(Channel.fromPath("$projectDir/assets/NO_FILE")).map{it[0]["model"] = "esmfold"; it}
        )
    }
    //
    // POST PROCESSING: generate visulaisation reports
    //
    if (!params.skip_visualisation){
        GENERATE_REPORT(
            ch_report_input.map{[it[0], it[1]]},
            ch_report_input.map{[it[0], it[2]]},
            ch_report_input.map{it[0].model},
            Channel.fromPath("$projectDir/assets/proteinfold_template.html").first()
        )
        ch_versions = ch_versions.mix(GENERATE_REPORT.out.versions)
    }

    if (params.foldseek_search == "easysearch"){
        ch_foldseek_db = channel.value([["id": params.foldseek_db],
                                        file(params.foldseek_db_path,
                                            checkIfExists: true)])

        FOLDSEEK_EASYSEARCH(
            ch_report_input
            .map{
                if (it[0].model == "esmfold")
                    [it[0], it[1]]
                else
                    [it[0], it[1][0]]
                },
            ch_foldseek_db
        )
    }

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
        params.input
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
