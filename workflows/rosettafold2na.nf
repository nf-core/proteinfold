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
        .multiqc
        .map { it[1] }
        .toSortedList()
        .map { 
            [ [ "model": "rosettafold2na" ], it.flatten() ] 
        }
        .set { ch_multiqc_report }

    RUN_ROSETTAFOLD2NA
        .out
        .pdb
        .map {
            def meta = it[0].clone();
            meta.model = "rosettafold2na";
            [meta, it[1]]
        }
        .set { ch_pdb_final }

    RUN_ROSETTAFOLD2NA
        .out
        .pae
        .map {
            def meta = it[0].clone();
            meta.model = "rosettafold2na";
            [meta, it[1]]
        }
        .set { ch_pae_final }
    
    emit:
    pdb            = ch_pdb_final      // channel: [ id, /path/to/*.pdb ]
    pae            = ch_pae_final      // channel: [ id, /path/to/*_pae.tsv ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
