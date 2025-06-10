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
include { SPLIT_MSA } from '../modules/local/msa_manager/split_msa'
include { MMSEQS_COLABFOLDSEARCH } from '../modules/local/mmseqs_colabfoldsearch'
include { MULTIFASTA_TO_CSV      } from '../modules/local/multifasta_to_csv'
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
    ch_colabfold_db // channel: [ path(colabfold_db) ]
    ch_uniref30     // channel: [ path(uniref30) ]
    msa_server

    main:
    ch_samplesheet.join(
        ch_samplesheet.map{[it[0], it[1].text.findAll {letter -> letter == ">" }.size()]}
    )
    .map{
        def meta = it[0].clone()
        meta.cnt = it[2]
        [meta, it[1]]
    }
    .branch{
        multimer: it[0].cnt > 1
        monomer: it[0].cnt == 1
    }
    .set{ch_input}

    if (!msa_server){
        MULTIFASTA_TO_CSV(
            ch_input.multimer
        )
        ch_versions = ch_versions.mix(MULTIFASTA_TO_CSV.out.versions)

        MMSEQS_COLABFOLDSEARCH (
                ch_input.monomer.mix(MULTIFASTA_TO_CSV.out.input_csv),
                ch_colabfold_db,
                ch_uniref30
        )
        ch_versions = ch_versions.mix(MMSEQS_COLABFOLDSEARCH.out.versions)

        SPLIT_MSA(
            MMSEQS_COLABFOLDSEARCH.out.a3m.filter{it[0].cnt > 1}
        )
        ch_versions = ch_versions.mix(SPLIT_MSA.out.versions)
        ch_input.monomer
            .join(MMSEQS_COLABFOLDSEARCH.out.a3m.filter{it[0].cnt == 1})
            .mix(
                ch_input.multimer.join(SPLIT_MSA.out.msa_csv)
            ).set{ch_prepare_fasta}

    }else{
        ch_input
        .multimer
        .mix(ch_input
        .monomer
        ).map{[it[0], it[1], []]}
        .set{ch_prepare_fasta}
    }

    BOLTZ_FASTA(
            ch_prepare_fasta
        )

    RUN_BOLTZ(
        BOLTZ_FASTA.out.formatted_fasta.map{[it[0], it[1]]},
        BOLTZ_FASTA.out.formatted_fasta.map{it[2]},
        ch_boltz_model,
        ch_boltz_ccd
    )

    RUN_BOLTZ
        .out
        .pdb
        .map{it[0].model = "boltz"; it}
        .set {ch_pdb}

    RUN_BOLTZ
        .out
        .msa
    .map{it[0].model = "boltz"; it}
    .set {ch_msa}

    RUN_BOLTZ
        .out
        .multiqc
        .map { it[1] }
        .collect(sort: true)
        .map { [ [ "model": "boltz"], it.flatten() ] }
        .set { ch_multiqc_report  }

    emit:
    versions        = ch_versions
    msa             = ch_msa
    structures      = RUN_BOLTZ.out.structures
    confidence      = RUN_BOLTZ.out.confidence
    multiqc_report  = ch_multiqc_report
    pdb             = ch_pdb
}
