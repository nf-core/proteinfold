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
    params.alphafold2_db
]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input file not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

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
include { RUN_AF2      } from '../modules/local/run_af2'
include { RUN_AF2_MSA  } from '../modules/local/run_af2_msa'
include { RUN_AF2_PRED } from '../modules/local/run_af2_pred'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

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
    if (params.alphafold2_model_preset != 'multimer') {
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

    // TODO The above code can be simplified with something such as the one below, modules need to be reviewed to
    // swallow the correct DBs, only RUN_AF2 should work like it is now
    //
    // SUBWORKFLOW: Download databases and params for Alphafold2
    //
    PREPARE_AF2_DBS ( )
    ch_versions = ch_versions.mix(PREPARE_AF2_DBS.out.versions)

    if (params.alphafold2_mode == 'standard') {
        //
        // SUBWORKFLOW: Run Alphafold2 standard mode
        //
        RUN_AF2 (
            ch_fasta,
            params.full_dbs,
            params.alphafold2_model_preset,
            PREPARE_AF2_DBS.out.params,
            PREPARE_AF2_DBS.out.bfd.ifEmpty([]),
            PREPARE_AF2_DBS.out.small_bfd.ifEmpty([]),
            PREPARE_AF2_DBS.out.mgnify,
            PREPARE_AF2_DBS.out.pdb70,
            PREPARE_AF2_DBS.out.pdb_mmcif,
            PREPARE_AF2_DBS.out.uniclust30,
            PREPARE_AF2_DBS.out.uniref90,
            PREPARE_AF2_DBS.out.pdb_seqres,
            PREPARE_AF2_DBS.out.uniprot,
        )
        ch_versions = ch_versions.mix(RUN_AF2.out.versions)
        ch_multiqc_rep = RUN_AF2.out.multiqc.collect()
    } else if (params.alphafold2_mode == 'split_msa_prediction') {
        //
        // SUBWORKFLOW: Run Alphafold2 split mode, MSA and predicition
        //
        RUN_AF2_MSA (
            ch_fasta,
            params.full_dbs,
            params.alphafold2_model_preset,
            PREPARE_AF2_DBS.out.params,
            PREPARE_AF2_DBS.out.bfd.ifEmpty([]),
            PREPARE_AF2_DBS.out.small_bfd.ifEmpty([]),
            PREPARE_AF2_DBS.out.mgnify,
            PREPARE_AF2_DBS.out.pdb70,
            PREPARE_AF2_DBS.out.pdb_mmcif,
            PREPARE_AF2_DBS.out.uniclust30,
            PREPARE_AF2_DBS.out.uniref90,
            PREPARE_AF2_DBS.out.pdb_seqres,
            PREPARE_AF2_DBS.out.uniprot

        )
        ch_versions = ch_versions.mix(RUN_AF2_MSA.out.versions)

        RUN_AF2_PRED (
            ch_fasta,
            params.full_dbs,
            params.alphafold2_model_preset,
            PREPARE_AF2_DBS.out.params,
            PREPARE_AF2_DBS.out.bfd.ifEmpty([]),
            PREPARE_AF2_DBS.out.small_bfd.ifEmpty([]),
            PREPARE_AF2_DBS.out.mgnify,
            PREPARE_AF2_DBS.out.pdb70,
            PREPARE_AF2_DBS.out.pdb_mmcif,
            PREPARE_AF2_DBS.out.uniclust30,
            PREPARE_AF2_DBS.out.uniref90,
            PREPARE_AF2_DBS.out.pdb_seqres,
            PREPARE_AF2_DBS.out.uniprot,
            RUN_AF2_MSA.out.features

        )
        ch_versions = ch_versions.mix(RUN_AF2_PRED.out.versions)
        ch_multiqc_rep = RUN_AF2_PRED.out.multiqc.collect()
    }

    //
    // MODULE: Pipeline reporting
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowAlphafold2.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowAlphafold2.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_rep)
    //ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
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
    if (params.hook_url) {
        NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
