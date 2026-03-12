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
include { PROTENIX_FASTA           } from '../modules/local/protenix_fasta'
include { SPLIT_MSA                } from '../modules/local/split_msa'
include { MMSEQS_COLABFOLDSEARCH   } from '../modules/local/mmseqs_colabfoldsearch'
include { MULTIFASTA_TO_CSV        } from '../modules/local/multifasta_to_csv'

//
// SUBWORKFLOW: Consisting entirely of nf-core/modules
//
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

//
// MODULE: Protenix
//
include { RUN_PROTENIX } from '../modules/local/run_protenix'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PROTENIX {

    take:
    ch_samplesheet      // channel: samplesheet read from --input
    ch_versions         // channel: [ path(versions.yml) ]
    ch_protenix_model   // channel: [ path(model_weights) ]
    ch_protenix_ccd     // channel: [ path(components.cif) ]
    ch_protenix_rdkit   // channel: [ path(components.cif.rdkit_mol.pkl) ]
    ch_colabfold_db     // channel: [ path(colabfold_db) ]
    ch_uniref30         // channel: [ path(uniref30) ]
    msa_server

    main:
    ch_samplesheet
        .branch { it ->
            fasta: it[1].extension == "fasta" || it[1].extension == "fa"
            json:  it[1].extension == "json"
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

    PROTENIX_FASTA(
            ch_prepare_fasta
        )
    ch_versions = ch_versions.mix(PROTENIX_FASTA.out.versions)

    ch_input_by_ext.json
        .map { meta, file -> [ meta, file, [] ] }  // already in JSON, no MSA
        .mix(PROTENIX_FASTA.out.protenix_json)      // newly converted from FASTA
        .set { ch_protenix_input }

    RUN_PROTENIX(
        ch_protenix_input.map { it -> [it[0], it[1]] },
        ch_protenix_input.map { it -> it[2] },
        ch_protenix_model,
        ch_protenix_ccd,
        ch_protenix_rdkit
    )

    RUN_PROTENIX
        .out
        .cif
        .map { it ->
            it[0].model = "protenix"
            it
        }
        .set {ch_cif}

    RUN_PROTENIX
        .out
        .top_ranked_pdb
        .map { it ->
            it[0].model = "protenix"
            it
        }
        .set {ch_top_ranked_pdb}

    RUN_PROTENIX
        .out
        .pae_raw
        .map { it ->
            it[0].model = "protenix"
            it
        }
        .set {ch_pae}

    RUN_PROTENIX
        .out
        .multiqc
        .map { it -> it[1] }
        .collect(sort: true)
        .map { it ->  [ [ "model": "protenix"], it.flatten() ] }
        .set { ch_multiqc_report  }

    ch_versions       = ch_versions.mix(RUN_PROTENIX.out.versions)

    // Wrap top_ranked_pdb as a list to match report_input format [meta, [pdb]]
    RUN_PROTENIX
        .out
        .top_ranked_pdb
        .map { meta, pdb ->
            def newMeta = meta.clone()
            newMeta.model = "protenix"
            [ newMeta, [ pdb ] ]
        }
        .set { ch_pdb }

    emit:
    versions        = ch_versions
    confidence      = RUN_PROTENIX.out.confidence
    multiqc_report  = ch_multiqc_report
    top_ranked_pdb  = ch_top_ranked_pdb
    pdb             = ch_pdb
    pae             = ch_pae
    cif             = ch_cif
}
