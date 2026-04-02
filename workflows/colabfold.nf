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
    ch_versions            // channel: [ path(versions.yml) ]
    colabfold_model_preset // string: Specifies the model preset to use for colabfold
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
        ch_versions = ch_versions.mix(MULTIFASTA_TO_CSV.out.versions)

        COLABFOLD_BATCH(
            MULTIFASTA_TO_CSV.out.input_csv,
            colabfold_model_preset,
            ch_colabfold_params,
            [],
            [],
            num_recycles
        )
        ch_versions = ch_versions.mix(COLABFOLD_BATCH.out.versions)

    } else {
        //
        // MODULE: Run mmseqs
        //
        //Multimer mode
        MULTIFASTA_TO_CSV(
            ch_samplesheet
        )
        ch_versions = ch_versions.mix(MULTIFASTA_TO_CSV.out.versions)
        MMSEQS_COLABFOLDSEARCH (
            MULTIFASTA_TO_CSV.out.input_csv,
            ch_colabfold_db,
            ch_uniref30
        )
        ch_versions = ch_versions.mix(MMSEQS_COLABFOLDSEARCH.out.versions)

        //
        // MODULE: Run colabfold
        //
        COLABFOLD_BATCH(
            MMSEQS_COLABFOLDSEARCH.out.a3m,
            colabfold_model_preset,
            ch_colabfold_params,
            ch_colabfold_db,
            ch_uniref30,
            num_recycles
        )
        ch_versions    = ch_versions.mix(COLABFOLD_BATCH.out.versions)
    }

    modeChannel(COLABFOLD_BATCH.out.top_ranked_pdb, "colabfold").set { ch_top_ranked_pdb }
    modeChannel(COLABFOLD_BATCH.out.pdb, "colabfold", true).set { ch_pdb_final }
    modeChannel(COLABFOLD_BATCH.out.msa, "colabfold").set { ch_msa_final }
    modeChannel(COLABFOLD_BATCH.out.pae, "colabfold").set { ch_pae_final }

    emit:
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ meta, /path/to/*.pdb ]
    pdb            = ch_pdb_final      // channel: [ id, /path/to/*.pdb ]
    msa            = ch_msa_final      // channel: [ meta, /path/to/*.pdb, /path/to/*_coverage.png ]
    pae            = ch_pae_final      // channel: [ id, /path/to/*_pae.tsv ]
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
