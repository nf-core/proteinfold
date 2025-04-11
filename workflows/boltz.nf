/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC } from '../modules/nf-core/multiqc/main'
include { BOLTZ_FASTA } from '../modules/local/data_convertor/boltz_fasta'
include { MMSEQS_COLABFOLDSEARCH } from '../modules/local/mmseqs_colabfoldsearch'

//
// SUBWORKFLOW: Consisting entirely of nf-core/modules
//
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

//
// MODULE: Boltz
//
include { RUN_BOLTZ } from '../modules/local/run_boltz'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow BOLTZ {
    
    take:
    ch_samplesheet  // channel: samplesheet read from --input
    ch_versions     // channel: [ path(versions.yml) ]
    ch_boltz_ccd    // channel: [ path(boltz_ccd) ]
    ch_boltz_model  // channel: [ path(model) ]
    ch_colabfold_params // channel: [ path(colabfold_params) ]
    ch_colabfold_db // channel: [ path(colabfold_db) ]
    ch_uniref30     // channel: [ path(uniref30) ]
    ch_dummy_file   // channel: [ path(NO_FILE) ]

    main:
    ch_multiqc_files = Channel.empty()
    
    BOLTZ_FASTA(
        ch_samplesheet
        .map{[it[0].id, it[1]]}
        .collect(flat: false)
        .map{
            [["id": "all-run"], 
             it.collect{item -> item[0]}, 
             it.collect{item -> item[1]}]
        }
    )

    // RUN_BOLTZ 
    RUN_BOLTZ(
        BOLTZ_FASTA.out.fasta.map{[["id": it[1].baseName], it[1]]},
        [],
        ch_boltz_model,
        ch_boltz_ccd
    )

    RUN_BOLTZ
        .out
        .pdb
        .combine(ch_dummy_file)
        .map {
            it[0]["model"] = "boltz"
            it
        }
        .set { ch_pdb }

    RUN_BOLTZ
        .out
        .multiqc
        .map { it[1] }
        .toSortedList()
        .map { [ [ "model":"boltz"], it.flatten() ] }
        .set { ch_multiqc_report  }

    emit:
    versions   = ch_versions
    msa        = ch_pdb
    structures = RUN_BOLTZ.out.structures
    confidence = RUN_BOLTZ.out.confidence
    multiqc_report = ch_multiqc_report
    pdb        = ch_pdb
} 
