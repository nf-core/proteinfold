/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { COLABFOLD_BATCH        } from '../modules/local/colabfold_batch'
include { MMSEQS_COLABFOLDSEARCH } from '../modules/local/mmseqs_colabfoldsearch'
include { MULTIFASTA_TO_CSV      } from '../modules/local/multifasta_to_csv'

include { modeChannel            } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

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

workflow COLABFOLD {

    take:
    ch_samplesheet          // channel: samplesheet read in from --input
    ch_colabfold_params    // channel: path(colabfold_params)
    ch_colabfold_db        // channel: path(colabfold_db)
    ch_uniref30            // channel: path(uniref30)
    num_recycles           // int: Number of recycles for colabfold

    main:

    if (params.use_msa_server) {
        //
        // MODULE: Run colabfold
        //

        MULTIFASTA_TO_CSV(
            ch_samplesheet
        )

        COLABFOLD_BATCH(
            MULTIFASTA_TO_CSV.out.input_csv
                .combine(ch_colabfold_params),
            num_recycles
        )

    } else {
        //
        // MODULE: Run mmseqs
        //
        MULTIFASTA_TO_CSV(
            ch_samplesheet
        )
        MMSEQS_COLABFOLDSEARCH (
            MULTIFASTA_TO_CSV.out.input_csv,
            ch_colabfold_db,
            ch_uniref30
        )

        //
        // MODULE: Run colabfold
        //
        COLABFOLD_BATCH(
            MMSEQS_COLABFOLDSEARCH.out.a3m
                .combine(ch_colabfold_params),
            num_recycles
        )
    }

    modeChannel(COLABFOLD_BATCH.out.top_ranked_pdb, "colabfold").set { ch_top_ranked_pdb }
    modeChannel(COLABFOLD_BATCH.out.pdb, "colabfold", true).set { ch_pdb_final }
    modeChannel(COLABFOLD_BATCH.out.msa, "colabfold").set { ch_msa_final }
    modeChannel(COLABFOLD_BATCH.out.pae, "colabfold").set { ch_pae_final }
    modeChannel(COLABFOLD_BATCH.out.iptms, "colabfold").set { ch_iptm_final }
    modeChannel(COLABFOLD_BATCH.out.ipsaes, "colabfold").set { ch_ipsae_final }
    modeChannel(COLABFOLD_BATCH.out.chainwise_iptms, "colabfold").set { ch_chainwise_iptm_final }
    modeChannel(COLABFOLD_BATCH.out.chainwise_ipsaes, "colabfold").set { ch_chainwise_ipsae_final }

    emit:
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ meta, /path/to/*.pdb ]
    pdb            = ch_pdb_final      // channel: [ id, /path/to/*.pdb ]
    msa            = ch_msa_final      // channel: [ meta, /path/to/*.pdb, /path/to/*_coverage.png ]
    pae            = ch_pae_final      // channel: [ id, /path/to/*_pae.tsv ]
    iptm           = ch_iptm_final     // channel: [ id, /path/to/*_iptm.tsv ]
    ipsae          = ch_ipsae_final    // channel: [ id, /path/to/*_ipsae.tsv ]
    chainwise_iptm = ch_chainwise_iptm_final // channel: [ id, /path/to/*_chainwise_iptm.tsv ]
    chainwise_ipsae = ch_chainwise_ipsae_final // channel: [ id, /path/to/*_chainwise_ipsae.tsv ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
