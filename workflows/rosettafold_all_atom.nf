/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { RUN_ROSETTAFOLD2NA } from '../modules/local/run_rosettafold2na.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW: ROSETTAFOLD2NA
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ROSETTAFOLD2NA {

    take:
        ch_samplesheet          // Channel: samplesheet read from --input
        ch_versions             // Channel: [ path(versions.yml) ]
        ch_bfd                  // Channel: path to BFD database files
        ch_uniref30             // Channel: path to UniRef30 database files
        ch_pdb100               // Channel: path to PDB100 database files
        ch_rf2na_weights        // Channel: path to RF2NA weights file
        ch_rna                  // Channel: path to RNA database files
        ch_dummy_file           // Channel: dummy file channel (if required downstream)

    main:
        ch_multiqc_files  = Channel.empty()
        ch_top_ranked_pdb = Channel.empty()
        ch_msa            = Channel.empty()
        ch_multiqc_report = Channel.empty()
        ch_pdb_msa        = Channel.empty()

        // Run the main RF2NA module with the required databases
        RUN_ROSETTAFOLD2NA (
            ch_samplesheet,
            ch_bfd,
            ch_uniref30,
            ch_pdb100,
            ch_rf2na_weights,
            ch_rna
        )

        // Merge version info from the RF2NA module with the global versions channel
        ch_versions = ch_versions.mix(RUN_ROSETTAFOLD2NA.out.versions)

        // Process PDB outputs: combine with a dummy file and tag each output with model "rosettafold2na"
        RUN_ROSETTAFOLD2NA.out.pdb
            .combine(ch_dummy_file)
            .map { meta, pdb, dummy ->
                meta.model = "rosettafold2na"
                [ meta["id"], meta, pdb, dummy ]
            }
            .set { ch_top_ranked_pdb }

        // Process MultiQC outputs: sort, flatten, and tag with model name
        RUN_ROSETTAFOLD2NA.out.multiqc
            .map { it[1] }
            .toSortedList()
            .map { [ [ model: "rosettafold2na" ], it.flatten() ] }
            .set { ch_multiqc_report }

        // Process PDB outputs for MSA: combine with dummy file and tag with model name
        RUN_ROSETTAFOLD2NA.out.pdb
            .combine(ch_dummy_file)
            .map { meta, pdb, dummy ->
                meta.model = "rosettafold2na"
                [ meta, pdb, dummy ]
            }
            .set { ch_pdb_msa }

        // Final mapping to create top-ranked PDB channel
        ch_pdb_msa
            .map { meta, pdb, dummy -> [ meta["id"], meta, pdb, dummy ] }
            .set { ch_top_ranked_pdb }

    emit:
        pdb_msa        = ch_pdb_msa        // Channel: [ meta, /path/to/*.pdb, dummy ]
        top_ranked_pdb = ch_top_ranked_pdb // Channel: [ id, meta, /path/to/*.pdb, dummy ]
        multiqc_report = ch_multiqc_report // Channel: MultiQC report file(s)
        versions       = ch_versions       // Channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
