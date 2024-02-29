/* //TODO: change header
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap       } from 'plugin/nf-validation'
include { fromSamplesheet        } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

// // TODO: remove Should be now in the common initialize
// // def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
// // def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
// // def summary_params = paramsSummaryMap(workflow)

// // // Print parameter summary log to screen
// // log.info logo + paramsSummaryLog(workflow) + citation

// // // Validate input parameters
// // WorkflowAlphafold2.initialise(params, log)

// // TODO: remove
// /*
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//     CONFIG FILES
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// */

// // ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
// // ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config ) : Channel.empty()
// // ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo )   : Channel.empty()
// // ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

// /*
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//     IMPORT LOCAL MODULES/SUBWORKFLOWS
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// */

// // // TODO: remove
// // // SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
// // //
// // include { PREPARE_ALPHAFOLD2_DBS } from '../subworkflows/local/prepare_alphafold2_dbs'

//
// MODULE: Local to the pipeline
//
include { RUN_ALPHAFOLD2         } from '../modules/local/run_alphafold2'
include { RUN_ALPHAFOLD2_MSA     } from '../modules/local/run_alphafold2_msa'
include { RUN_ALPHAFOLD2_PRED    } from '../modules/local/run_alphafold2_pred'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC } from '../modules/nf-core/multiqc/main'
// TODO: remove
// include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// TODO: remove
// // Info required for completion email and summary
// def multiqc_report = []
// workflow ALPHAFOLD2 {
    
//     take:
//     ch_versions
//     ch_full_dbs
//     ch_alphafold2_mode
//     // ch_alphafold2_model_preset,
//     // ch_params,
//     // ch_bfd,
//     // ch_small_bfd,
//     // ch_mgnify,
//     // ch_pdb70,
//     // ch_pdb_mmcif,
//     // ch_uniref30,
//     // ch_uniref90,
//     // ch_pdb_seqres,
//     // ch_uniprot

//     main:
//     println("culo.........")
//     ch_multiqc_files = Channel.empty()
//     ch_versions = Channel.empty()

//     emit:
//     multiqc_report = ch_multiqc_files // channel: /path/to/multiqc_report.html
//     versions       = ch_versions  
// }

workflow ALPHAFOLD2 {

    take:
    ch_versions
    ch_full_dbs
    ch_alphafold2_mode
    ch_alphafold2_model_preset
    ch_alphafold2_params
    ch_bfd
    ch_small_bfd
    ch_mgnify
    ch_pdb70
    ch_pdb_mmcif
    ch_uniref30
    ch_uniref90
    ch_pdb_seqres
    ch_uniprot

    main:
    ch_multiqc_files = Channel.empty()
    
    //
    // Create input channel from input file provided through params.input
    //
    Channel
        .fromSamplesheet("input")
        .set { ch_fasta }

    if (ch_alphafold2_model_preset != 'multimer') {
        ch_fasta
            .map {
                meta, fasta ->
                [ meta, fasta.splitFasta(file:true) ]
            }
            .transpose()
            .set { ch_fasta }
    }

    //
    // SUBWORKFLOW: Download databases and params for Alphafold2
    //
    // PREPARE_ALPHAFOLD2_DBS ( ) //TODO: remove
    // ch_versions = ch_versions.mix(PREPARE_ALPHAFOLD2_DBS.out.versions)
    if (ch_alphafold2_mode == 'standard') {
        //
        // SUBWORKFLOW: Run Alphafold2 standard mode
        //
        RUN_ALPHAFOLD2 (
            ch_fasta,
            ch_full_dbs,
            ch_alphafold2_model_preset,
            ch_alphafold2_params,
            ch_bfd,
            ch_small_bfd,
            ch_mgnify,
            ch_pdb70,
            ch_pdb_mmcif,
            ch_uniref30,
            ch_uniref90,
            ch_pdb_seqres,
            ch_uniprot
        )
        ch_multiqc_rep = RUN_ALPHAFOLD2.out.multiqc.collect()
        ch_versions    = ch_versions.mix(RUN_ALPHAFOLD2.out.versions)
        
    } else if (ch_alphafold2_mode == 'split_msa_prediction') {
        //
        // SUBWORKFLOW: Run Alphafold2 split mode, MSA and predicition
        //
        RUN_ALPHAFOLD2_MSA (
            ch_fasta,
            ch_full_dbs,
            ch_alphafold2_model_preset,
            ch_alphafold2_params,
            ch_bfd,
            ch_small_bfd,
            ch_mgnify,
            ch_pdb70,
            ch_pdb_mmcif,
            ch_uniref30,
            ch_uniref90,
            ch_pdb_seqres,
            ch_uniprot
        )
        ch_multiqc_rep = RUN_ALPHAFOLD2_MSA.out.multiqc.collect()
        ch_versions    = ch_versions.mix(RUN_ALPHAFOLD2_MSA.out.versions)
        
        RUN_ALPHAFOLD2_PRED (
            ch_fasta,
            ch_full_dbs,
            ch_alphafold2_model_preset,
            ch_alphafold2_params,
            ch_bfd,
            ch_small_bfd,
            ch_mgnify,
            ch_pdb70,
            ch_pdb_mmcif,
            ch_uniref30,
            ch_uniref90,
            ch_pdb_seqres,
            ch_uniprot,
            RUN_ALPHAFOLD2_MSA.out.features
        )
        ch_multiqc_rep = RUN_ALPHAFOLD2_PRED.out.multiqc.collect()
        ch_versions = ch_versions.mix(RUN_ALPHAFOLD2_PRED.out.versions)        
    }

    // TODO: remove
    // //
    // // MODULE: Pipeline reporting
    // //
    // CUSTOM_DUMPSOFTWAREVERSIONS (
    //     ch_versions.unique().collectFile(name: 'collated_versions.yml')
    // )
    
    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_proteinfold_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_report        = Channel.empty()
    ch_multiqc_config        = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath( params.multiqc_config ) : Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo )   : Channel.empty()
    summary_params           = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary      = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_rep)

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    ch_multiqc_report = MULTIQC.out.report.toList()

    emit:
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

// TODO: remove
// /*
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//     COMPLETION EMAIL AND SUMMARY
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// */

// workflow.onComplete {
//     if (params.email || params.email_on_fail) {
//         NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
//     }
//     NfcoreTemplate.dump_parameters(workflow, params)
//     NfcoreTemplate.summary(workflow, params, log)
//     if (params.hook_url) {
//         NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
//     }
// }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
