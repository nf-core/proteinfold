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
//
// SUBWORKFLOW: Consisting entirely of nf-core/modules
//
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { MSA                    } from '../subworkflows/local/msa'

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
    mmseq_batch_size

    main:
    ch_multiqc_files = Channel.empty()

    ch_samplesheet
        .branch {
            fasta: it[1].extension == "fasta" || it[1].extension == "fa"
            yaml: it[1].extension == "yaml" || it[1].extension == "yml"
        }
        .set { ch_input_by_ext }

    if (!msa_server){
        MSA(
            ch_samplesheet,
            ch_colabfold_db,
            ch_uniref30,
            mmseq_batch_size
        )

        ch_versions = ch_versions.mix(MSA.out.versions)
        MSA.out.formated_input
        .branch{
            multimer: it[0].cnt > 1
            monomer: it[0].cnt == 1
        }
        .set{ch_input}

        SPLIT_MSA(
            MSA.out.a3m.filter{it[0].cnt > 1}
        )
        ch_versions = ch_versions.mix(SPLIT_MSA.out.versions)
        ch_input.monomer
            .join(MSA.out.a3m.filter{it[0].cnt == 1})
            .mix(
                ch_input.multimer.join(SPLIT_MSA.out.msa_csv)
            ).set{ch_prepare_fasta}

    }else{
        ch_input_by_ext.fasta
            .join(
                ch_input_by_ext.fasta
                    .map { meta, file ->
                        [
                            meta,
                            file.text.findAll { letter -> letter == ">" }.size()
                        ]
                    }
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

        ch_input_by_ext.yaml.mix(
        ch_input
        .multimer
        .mix(ch_input
        .monomer
        )).map{[it[0], it[1], []]}
        .set{ch_prepare_fasta}
    }

    BOLTZ_FASTA(
        ch_prepare_fasta
    )

    def ch_yaml_indexed = ch_input_by_ext.yaml
        .map { meta, file ->
            [meta.id, [meta, file, []]]
        }


    def ch_fasta_indexed = BOLTZ_FASTA.out.formatted_fasta.map { meta, file, msa ->
        [meta.id, [meta, file, msa]]
    }

    def ch_boltz_input_yaml_with_msa = ch_yaml_indexed
        .join(ch_fasta_indexed, remainder: true)
        .map { id, yamlEntry, fastaEntry ->
            def (yamlMeta, yamlFile, unusedMsa) = yamlEntry ?: fastaEntry
            def (unusedMeta, unusedFile, msa) = fastaEntry
            [yamlMeta, yamlFile, msa]
        }
    .set { ch_boltz_input }

    RUN_BOLTZ(
        ch_boltz_input.map{[it[0], it[1]]},
        ch_boltz_input.map{it[2]},
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
