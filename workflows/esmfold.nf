/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_ESMFOLD               } from '../modules/local/run_esmfold'
include { MULTIFASTA_TO_SINGLEFASTA } from '../modules/local/multifasta_to_singlefasta'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ESMFOLD {

    take:
    ch_samplesheet    // channel: samplesheet read in from --input
    ch_versions       // channel: [ path(versions.yml) ]
    ch_esmfold_params // directory: /path/to/esmfold/params/
    ch_num_recycles   // int: Number of recycles for esmfold

    main:
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: Run esmfold
    //
    if (params.esmfold_model_preset != 'monomer') {
        MULTIFASTA_TO_SINGLEFASTA(
            ch_samplesheet
        )
        ch_versions = ch_versions.mix(MULTIFASTA_TO_SINGLEFASTA.out.versions)
        RUN_ESMFOLD(
            MULTIFASTA_TO_SINGLEFASTA.out.input_fasta,
            ch_esmfold_params,
            ch_num_recycles
        )
        ch_versions = ch_versions.mix(RUN_ESMFOLD.out.versions)
    } else {
        RUN_ESMFOLD(
            ch_samplesheet,
            ch_esmfold_params,
            ch_num_recycles
        )
        ch_versions = ch_versions.mix(RUN_ESMFOLD.out.versions)
    }

    RUN_ESMFOLD
        .out
        .pdb
        .map{
            meta = it[0].clone();
            meta.model = "esmfold";
            [meta, it[1]]
        }
        .set{ch_pdb_final}

    RUN_ESMFOLD
        .out
        .multiqc
        .map { it[1] }
        .toSortedList()
        .map { [ [ "model": "esmfold"], it.flatten() ] }
        .set { ch_multiqc_report  }

    emit:
    pdb            = ch_pdb_final   // channel: [ id, /path/to/*.pdb ]
    multiqc_report = ch_multiqc_report   // channel: /path/to/multiqc_report.html
    versions       = ch_versions         // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
