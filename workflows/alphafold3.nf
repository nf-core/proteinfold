/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { FASTA_TO_ALPHAFOLD3_JSON          } from '../modules/local/fasta_to_alphafold3_json'
include { RUN_ALPHAFOLD3                    } from '../modules/local/run_alphafold3'
include { MMCIF2PDB as MMCIF2PDB_TOP_RANKED } from '../modules/local/mmcif2pdb/main.nf'
include { MMCIF2PDB as MMCIF2PDB_MODELS     } from '../modules/local/mmcif2pdb/main.nf'

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

workflow ALPHAFOLD3 {

    take:
    ch_samplesheet       // channel: samplesheet read in from --input
    ch_versions          // channel: [ path(versions.yml) ]
    ch_alphafold3_params // channel: path(alphafold2_params)
    ch_small_bfd         // channel: path(small_bfd)
    ch_mgnify            // channel: path(mgnify)
    ch_mmcif_files       // channel: path(mmcif_files)
    ch_uniref90          // channel: path(uniref90)
    ch_pdb_seqres        // channel: path(pdb_seqres)
    ch_uniprot           // channel: path(uniprot)

    main:
    ch_pdb_final      = Channel.empty()
    ch_top_ranked_pdb = Channel.empty()
    ch_msa_final      = Channel.empty()
    ch_multiqc_report = Channel.empty()
    ch_versions       = Channel.empty()

    FASTA_TO_ALPHAFOLD3_JSON(ch_samplesheet)
    ch_versions       = ch_versions.mix(FASTA_TO_ALPHAFOLD3_JSON.out.versions)

    //
    // SUBWORKFLOW: Run Alphafold2 standard mode
    //
    RUN_ALPHAFOLD3 (
        FASTA_TO_ALPHAFOLD3_JSON.out.json,
        ch_alphafold3_params,
        ch_small_bfd,
        ch_mgnify,
        ch_mmcif_files,
        ch_uniref90,
        ch_pdb_seqres,
        ch_uniprot
    )
    ch_versions = ch_versions.mix(RUN_ALPHAFOLD3.out.versions)

    // Convert mmcif to pdbs
    RUN_ALPHAFOLD3
            .out
            .cif
            .groupTuple()
            .map {
                meta, files ->
                [ meta, files.flatten() ]
            }

    // Convert models mmcifs to pdbs
    MMCIF2PDB_MODELS (
        RUN_ALPHAFOLD3
            .out
            .cif
            .groupTuple()
            .map {
                meta, files ->
                [ meta, files.flatten() ]
            }
    )
    ch_versions = ch_versions.mix(MMCIF2PDB_MODELS.out.versions)

    MMCIF2PDB_MODELS
        .out
        .pdb
        .map {
            def meta   = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_pdb_final }

    // Convert top ranked mmcif to pdb
    MMCIF2PDB_TOP_RANKED (
        RUN_ALPHAFOLD3
            .out
            .top_ranked_cif
    )
    ch_versions = ch_versions.mix(MMCIF2PDB_TOP_RANKED.out.versions)

    MMCIF2PDB_TOP_RANKED
        .out
        .pdb
        .map {
            def meta = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_top_ranked_pdb }

    // Prepare msa input
    RUN_ALPHAFOLD3
        .out
        .msa
        .map {
            def meta = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_msa_final }

    // Prepare report input
    RUN_ALPHAFOLD3
        .out
        .multiqc
        .map { it[1] }
        .toSortedList()
        .map { [ [ "model": "alphafold3" ], it.flatten() ] }
        .set { ch_multiqc_report }

    emit:
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ id, /path/to/*.pdb ]
    pdb            = ch_pdb_final      // channel: [ meta, /path/to/*.pdb, ...,/path/to/*.pdb ]
    msa            = ch_msa_final      // channel: [ meta, /path/to/*.pdb, /path/to/*_coverage.png ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
