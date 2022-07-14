/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowColabfold.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [
    params.input,
    // params.skip_download ? params.colabfold_db : ''
    params.colabfold_db
]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input file not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'
include { PREPARE_COLABFOLD_DBS } from '../subworkflows/local/prepare_colabfold_dbs'

//
// MODULE: Local to the pipeline
//
include { COLABFOLD_BATCH         } from '../modules/local/colabfold_batch'
include { MMSEQS_COLABFOLDSEARCH } from '../modules/local/mmseqs_colabfoldsearch'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC                     } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow COLABFOLD {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    PREPARE_COLABFOLD_DBS ( )

    if (params.mode == 'colabfold_webserver') {
        //
        // MODULE: Run colabfold
        //
        COLABFOLD_BATCH(
            INPUT_CHECK.out.fastas,
            params.model_type,
            PREPARE_COLABFOLD_DBS.out.params,
            [],
            [],
            params.num_recycle
        )
    } else if (params.mode == 'colabfold_local') {
        //
        // MODULE: Run mmseqs
        //
        MMSEQS_COLABFOLDSEARCH (
            INPUT_CHECK.out.fastas,
            PREPARE_COLABFOLD_DBS
                .out
                .params
                .combine(PREPARE_COLABFOLD_DBS.out.colabfold_db, by: 0)
                .combine(PREPARE_COLABFOLD_DBS.out.uniref30, by: 0).flatten().first()
            // PREPARE_COLABFOLD_DBS
            //     .out
            //     .colabfold_db
            //     .combine(PREPARE_COLABFOLD_DBS.out.uniref30)
            // PREPARE_COLABFOLD_DBS.out.colabfold_db.first(), //TODO check if this only needs colabfold db or also uniref30
            // PREPARE_COLABFOLD_DBS.out.uniref30.first(),
            params.db_load_mode
        )

        //
        // MODULE: Run colabfold
        //
        COLABFOLD_BATCH(
            MMSEQS_COLABFOLDSEARCH.out.a3m,
            params.model_type,
            PREPARE_COLABFOLD_DBS
                .out
                .params
                .combine(PREPARE_COLABFOLD_DBS.out.colabfold_db, by: 0)
                .combine(PREPARE_COLABFOLD_DBS.out.uniref30, by: 0).flatten().first()
            // PREPARE_COLABFOLD_DBS.out.params,
            // PREPARE_COLABFOLD_DBS.out.colabfold_db.first(),
            // PREPARE_COLABFOLD_DBS.out.uniref30.first(),
            // PREPARE_COLABFOLD_DBS.out.colabfold_db.first(),
            // PREPARE_COLABFOLD_DBS.out.uniref30.first(),
            params.num_recycle
        )
    }
    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowColabfold.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    //ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    MULTIQC (
        ch_multiqc_files.collect()
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
