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
include { BOLTZ_FASTA } from '../modules/local/boltz_fasta'
include { SPLIT_MSA } from '../modules/local/split_msa'
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
    ch_boltz2_aff   // channel: [ path(boltz2_aff) ]
    ch_boltz2_conf  // channel: [ path(boltz2_conf) ]
    ch_mols         // channel: [ path(mols) ]
    ch_colabfold_db // channel: [ path(colabfold_db) ]
    ch_uniref30     // channel: [ path(uniref30) ]
    msa_server

    main:
    ch_samplesheet
        .branch { it ->
            fasta: it[1].extension == "fasta" || it[1].extension == "fa"
            yaml: it[1].extension == "yaml" || it[1].extension == "yml"
        }
        .set { ch_input_by_ext }

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
        .map { it ->
            def meta = it[0].clone()
            meta.cnt = it[2]
            [meta, it[1]]
        }
        .branch { it ->
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
            MMSEQS_COLABFOLDSEARCH.out.a3m
        )
        ch_versions = ch_versions.mix(SPLIT_MSA.out.versions)
        ch_input.monomer
            .join(SPLIT_MSA.out.msa_csv)
            .mix(
                ch_input.multimer.join(SPLIT_MSA.out.msa_csv)
            ).set{ch_prepare_fasta}

    }else{
        ch_input
            .multimer
            .mix(ch_input.monomer)
            .map { it ->
                [it[0], it[1], []]
            }
            .set{ch_prepare_fasta}
    }

    BOLTZ_FASTA(
            ch_prepare_fasta
        )

    ch_input_by_ext.yaml
        .map { meta, file -> [ meta, file, [] ] }  // already in YAML
        .mix(BOLTZ_FASTA.out.formatted_fasta)    // newly converted from FASTA
        .set { ch_boltz_input }

    RUN_BOLTZ(
        ch_boltz_input,
        ch_boltz_model,
        ch_boltz_ccd,
        ch_boltz2_aff,
        ch_boltz2_conf,
        ch_mols
    )

    RUN_BOLTZ
        .out
        .pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set {ch_pdb}

    RUN_BOLTZ
        .out
        .top_ranked_pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_top_ranked_pdb }

    RUN_BOLTZ
        .out
        .msa_raw
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_msa }

    RUN_BOLTZ
        .out
        .pae_raw
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_pae }

    ch_versions       = ch_versions.mix(RUN_BOLTZ.out.versions)

    emit:
    versions        = ch_versions
    msa             = ch_msa
    structures      = RUN_BOLTZ.out.structures
    confidence      = RUN_BOLTZ.out.confidence
    top_ranked_pdb  = ch_top_ranked_pdb
    pdb             = ch_pdb
    pae             = ch_pae
}
