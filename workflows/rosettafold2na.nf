/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_ROSETTAFOLD2NA } from '../modules/local/run_rosettafold2na'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ROSETTAFOLD2NA {

    take:
    ch_samplesheet          // channel: samplesheet read in from --input
    ch_interactions         // channel: interactions read in from --interactions
    ch_versions             // channel: [ path(versions.yml) ]
    ch_bfd                  // channel: path(bfd)
    ch_uniref30             // channel: path(uniref30)
    ch_pdb100               // channel: path(pdb100)
    ch_rna                  // channel: path(rna)
    ch_rf2na_weights        // channel: path(rf2na_weights)
    ch_dummy_file           // channel: path(NO_FILE)

    main:
    ch_multiqc_files  = Channel.empty()
    ch_top_ranked_pdb = Channel.empty()
    ch_pdb_msa        = Channel.empty()
    ch_multiqc_report = Channel.empty()

    ch_samplesheet_reshaped = ch_samplesheet.map {
        meta, file -> [ meta.id, file ] }

    ch_protein_interaction = ch_interactions
                                .map {
                                    [ it.protein_id, it.interaction_id, it.interaction_type ]
                                }
                                .join(ch_samplesheet_reshaped, by: 0)
                                .map {
                                    [ it[1], it[0], it[2], it[3] ] // [ protein_id, interaction_id, interaction_type, file ]
                                }
                                .join(ch_samplesheet_reshaped, by: 0)
                                .map {
                                    [ [ id: it[1], interaction_id: it[0], interaction_type: it[2] ], it[3], it[4] ] // [ protein_id, interaction_id, interaction_type, file ]
                                }

    RUN_ROSETTAFOLD2NA (
        ch_protein_interaction,
        ch_bfd,
        ch_uniref30,
        ch_pdb100,
        ch_rna,
        ch_rf2na_weights
    )
    ch_versions = ch_versions.mix(RUN_ROSETTAFOLD2NA.out.versions)

    RUN_ROSETTAFOLD2NA
        .out
        .pdb
        .combine(ch_dummy_file)
        .map {
            it[0]["model"] = "rosettafold2na"
            [ it[0]["id"], it[0], it[1], it[2] ]
        }
        .set { ch_top_ranked_pdb }

    RUN_ROSETTAFOLD2NA
        .out
        .multiqc
        .map { it[1] }
        .toSortedList()
        .map { [ [ "model": "rosettafold2na" ], it.flatten() ] }
        .set { ch_multiqc_report }

    RUN_ROSETTAFOLD2NA
        .out
        .pdb
        .combine(ch_dummy_file)
        .map {
            it[0]["model"] = "rosettafold2na"
            it
        }
        .set { ch_pdb_msa }

    ch_pdb_msa
        .map { [ it[0]["id"], it[0], it[1], it[2] ] }
        .set { ch_top_ranked_pdb }

    emit:
    pdb_msa        = ch_pdb_msa        // channel: [ meta, /path/to/*.pdb, dummy_file ]
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ id, meta, /path/to/*.pdb, dummy_file ]
    multiqc_report = ch_multiqc_report // channel: [ [ model: "rosettafold2na" ], [ /path/to/*_plddt_mqc.tsv ] ]
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
