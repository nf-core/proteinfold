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
include { resolveModelPresetByFastaEntities } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

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
    ch_colabfold_params    // channel: path(colabfold_params)
    ch_colabfold_db        // channel: path(colabfold_db)
    ch_uniref30            // channel: path(uniref30)
    num_recycles           // int: Number of recycles for colabfold

    main:
    ch_multiqc_report = channel.empty()
    ch_samplesheet_with_param_group = ch_samplesheet
        .map { meta, fasta ->
            def resolved_model_preset = resolveModelPresetByFastaEntities(fasta, 'monomer', 'multimer')
            [ meta, fasta, resolved_model_preset ]
        }

    if (params.use_msa_server) {
        //
        // MODULE: Run colabfold
        //

        MULTIFASTA_TO_CSV(
            ch_samplesheet_with_param_group.map { meta, fasta, _param_group ->
                [ meta, fasta ]
            }
        )
        ch_versions = ch_versions.mix(MULTIFASTA_TO_CSV.out.versions)

        COLABFOLD_BATCH(
            MULTIFASTA_TO_CSV.out.input_csv
                .join(ch_samplesheet_with_param_group.map { meta, _fasta, param_group -> [ meta, param_group ] })
                .map { meta, input_csv, param_group ->
                    [ param_group, meta, input_csv ]
                }
                .combine(ch_colabfold_params, by: 0)
                .map { _preset_group, meta, input_csv, colabfold_params ->
                    [ meta, input_csv, colabfold_params ]
                },
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
            ch_samplesheet_with_param_group.map { meta, fasta, _param_group ->
                [ meta, fasta ]
            }
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
            MMSEQS_COLABFOLDSEARCH.out.a3m
                .join(ch_samplesheet_with_param_group.map { meta, _fasta, param_group -> [ meta, param_group ] })
                .map { meta, a3m, param_group ->
                    [ param_group, meta, a3m ]
                }
                .combine(ch_colabfold_params, by: 0)
                .map { _preset_group, meta, a3m, colabfold_params ->
                    [ meta, a3m, colabfold_params ]
                },
            ch_colabfold_db,
            ch_uniref30,
            num_recycles
        )
        ch_versions    = ch_versions.mix(COLABFOLD_BATCH.out.versions)
    }

    COLABFOLD_BATCH
        .out
        .top_ranked_pdb
        .map { it ->
            def meta_clone = it[0].clone();
            meta_clone.model = "colabfold";
            [ meta_clone, it[1] ]
        }
        .set { ch_top_ranked_pdb }

    COLABFOLD_BATCH
        .out
        .pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "colabfold";
            def files = (it[1] instanceof List) ? it[1] : [ it[1] ]
            [ meta, files ]
        }
        .set { ch_pdb_final }

    modeChannel(COLABFOLD_BATCH.out.msa, "colabfold").set { ch_msa_final }
    modeChannel(COLABFOLD_BATCH.out.pae, "colabfold").set { ch_pae_final }

    COLABFOLD_BATCH
        .out
        .multiqc
        .map { it -> it[1] }
        .toSortedList()
        .map { it ->
            [ [ "model":"colabfold"], it.flatten() ]
        }
        .set { ch_multiqc_report  }

    emit:
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ meta, /path/to/*.pdb ]
    pdb            = ch_pdb_final      // channel: [ id, /path/to/*.pdb ]
    msa            = ch_msa_final      // channel: [ meta, /path/to/*.pdb, /path/to/*_coverage.png ]
    pae            = ch_pae_final      // channel: [ id, /path/to/*_pae.tsv ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
