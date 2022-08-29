/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowAlphafold2.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [
    params.input,
    params.af2_db,
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
include { PREPARE_AF2_DBS } from '../subworkflows/local/prepare_af2_dbs'

//
// MODULE: Local to the pipeline
//
// TODO name the module as the containing file
// TODO Split them in three local modules, nf-core standard is one module per file since eventually they can become
// official modules
include { RUN_AF2; RUN_AF2_MSA; RUN_AF2_PRED } from '../modules/local/af2.nf'

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

workflow ALPHAFOLD2 {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    if (params.model_preset != 'multimer') {
        INPUT_CHECK (
            ch_input
        )
        .fastas
        .map {
            meta, fasta ->
            [ meta, fasta.splitFasta(file:true) ]
        }
        .transpose()
        .set { ch_fasta }
    } else {
        INPUT_CHECK (
            ch_input
        )
        .fastas
        .set { ch_fasta }
    }
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // SUBWORKFLOW: Download databases and params for Alphafold2
    //
    if (!params.skip_download) {
        DOWNLOAD_AF2_DBS_AND_PARAMS (
            params.af2_db,
            params.full_dbs
        )

        //
        // MODULE: Run Alphafold2
        //
        if (!params.standard_af2) {

            RUN_AF2_MSA (
                ch_fasta,
                params.full_dbs,
                params.model_preset,
                DOWNLOAD_AF2_DBS_AND_PARAMS.out
            )

            RUN_AF2_PRED (
                ch_fasta,
                params.full_dbs,
                params.model_preset,
                DOWNLOAD_AF2_DBS_AND_PARAMS.out,
                RUN_AF2_MSA.out.features
            )

        } else {
            RUN_AF2 (
                ch_fasta,
                params.max_template_date,
                params.full_dbs,
                params.model_preset,
                DOWNLOAD_AF2_DBS_AND_PARAMS.out
            )
        }

    } else {
        if (!params.standard_af2) {
            RUN_AF2_MSA (
                ch_fasta,
                params.full_dbs,
                params.model_preset,
                params.af2_db
            )

            RUN_AF2_PRED (
                ch_fasta,
                params.full_dbs,
                params.model_preset,
                params.af2_db,
                RUN_AF2_MSA.out.features
            )

        } else{
            RUN_AF2 (
                ch_fasta,
                params.max_template_date,
                params.full_dbs,
                params.model_preset,
                params.af2_db
            )
        }
    }

    // TODO The above code can be simplified with something such as the one below, modules need to be reviewed to
    // swallow the correct DBs, only RUN_AF2 should work like it is now
    // //
    // // SUBWORKFLOW: Download databases and params for Alphafold2
    // //
    // PREPARE_AF2_DBS ( )

    // //
    // // MODULE: Run Alphafold2
    // //
    // if (!params.standard_af2) {

    //     RUN_AF2_MSA (
    //         ch_fasta,
    //         params.full_dbs,
    //         params.model_preset,
    //         PREPARE_AF2_DBS.out.params,
    //         PREPARE_AF2_DBS.out.bfd.ifEmpty([]),
    //         PREPARE_AF2_DBS.out.bfd_small.ifEmpty([]),
    //         PREPARE_AF2_DBS.out.mgnify,
    //         PREPARE_AF2_DBS.out.pdb70,
    //         PREPARE_AF2_DBS.out.pdb_mmcif,
    //         PREPARE_AF2_DBS.out.uniclust30,
    //         PREPARE_AF2_DBS.out.uniref90,
    //         PREPARE_AF2_DBS.out.pdb_seqres,
    //         PREPARE_AF2_DBS.out.uniprot
    //     )

    //     RUN_AF2_PRED (
    //         ch_fasta,
    //         params.full_dbs,
    //         params.model_preset,
    //         PREPARE_AF2_DBS.out.params,
    //         PREPARE_AF2_DBS.out.bfd.ifEmpty([]),
    //         PREPARE_AF2_DBS.out.bfd_small.ifEmpty([]),
    //         PREPARE_AF2_DBS.out.mgnify,
    //         PREPARE_AF2_DBS.out.pdb70,
    //         PREPARE_AF2_DBS.out.pdb_mmcif,
    //         PREPARE_AF2_DBS.out.uniclust30,
    //         PREPARE_AF2_DBS.out.uniref90,
    //         PREPARE_AF2_DBS.out.pdb_seqres,
    //         PREPARE_AF2_DBS.out.uniprot,
    //         RUN_AF2_MSA.out.features
    //     )

    // } else {
    //     RUN_AF2 (
    //         ch_fasta,
    //         params.max_template_date,
    //         params.full_dbs,
    //         params.model_preset,
    //         PREPARE_AF2_DBS.out.params,
    //         PREPARE_AF2_DBS.out.bfd.ifEmpty([]),
    //         PREPARE_AF2_DBS.out.bfd_small.ifEmpty([]),
    //         PREPARE_AF2_DBS.out.mgnify,
    //         PREPARE_AF2_DBS.out.pdb70,
    //         PREPARE_AF2_DBS.out.pdb_mmcif,
    //         PREPARE_AF2_DBS.out.uniclust30,
    //         PREPARE_AF2_DBS.out.uniref90,
    //         PREPARE_AF2_DBS.out.pdb_seqres,
    //         PREPARE_AF2_DBS.out.uniprot
    //     )
    // }

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowAlphafold2.paramsSummaryMultiqc(workflow, summary_params)
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
