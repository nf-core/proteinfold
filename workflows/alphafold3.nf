/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { FASTA_TO_ALPHAFOLD3_JSON                } from '../modules/local/fasta_to_alphafold3_json'
include { RUN_ALPHAFOLD3_DATAPIPELINE             } from '../modules/local/run_alphafold3_datapipeline'
include { RUN_ALPHAFOLD3_INFERENCE                } from '../modules/local/run_alphafold3_inference'

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
    ch_alphafold3_params // channel: path(alphafold3_params)
    ch_small_bfd         // channel: path(small_bfd)
    ch_mgnify            // channel: path(mgnify)
    ch_mmcif_files       // channel: path(mmcif_files)
    ch_uniref90          // channel: path(uniref90)
    ch_pdb_seqres        // channel: path(pdb_seqres)
    ch_uniprot           // channel: path(uniprot)

    main:
    ch_structure_final      = channel.empty()
    ch_top_ranked_structure = channel.empty()
    ch_msa_final           = channel.empty()
    ch_multiqc_report      = channel.empty()

    ch_samplesheet
        .branch { it ->
            fasta: it[1].extension == "fasta" || it[1].extension == "fa"
            json: it[1].extension == "json"
    }.set { ch_input_by_ext }

    FASTA_TO_ALPHAFOLD3_JSON(ch_input_by_ext.fasta)

    ch_json = ch_input_by_ext.json.mix(FASTA_TO_ALPHAFOLD3_JSON.out.json)

    //
    // MODULE: Run AlphaFold3 data pipeline (MSA + template search)
    //
    RUN_ALPHAFOLD3_DATAPIPELINE (
        ch_json,
        ch_small_bfd,
        ch_mgnify,
        ch_mmcif_files,
        ch_uniref90,
        ch_pdb_seqres,
        ch_uniprot
    )

    //
    // MODULE: Run AlphaFold3 inference using pre-computed data JSON
    //
    RUN_ALPHAFOLD3_INFERENCE (
        RUN_ALPHAFOLD3_DATAPIPELINE.out.data_json,
        ch_alphafold3_params
    )

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

    MMCIF2PDB_MODELS
        .out
        .pdb
        .map { it ->
            def meta   = it[0].clone();
            meta.model = "alphafold3";
            def files = (it[1] instanceof List) ? it[1] : [ it[1] ]
            [ meta, files ]
        }
        .set { ch_structure_final }

    // Convert top ranked mmcif to pdb
    MMCIF2PDB_TOP_RANKED (
        RUN_ALPHAFOLD3
            .out
            .top_ranked_cif
    )

    MMCIF2PDB_TOP_RANKED
        .out
        .pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_top_ranked_structure }

    // Prepare msa input
    RUN_ALPHAFOLD3_INFERENCE
        .out
        .msa
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_msa_final }

    // Prepare multiqc input
    RUN_ALPHAFOLD3_INFERENCE
        .out
        .multiqc
        .map { it -> it[1] }
        .toSortedList()
        .map { it ->
            [ [ "model": "alphafold3" ], it.flatten() ]
        }
        .set { ch_multiqc_report }

    // Prepare pae input
    RUN_ALPHAFOLD3_INFERENCE
        .out
        .pae
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_pae_final }

    RUN_ALPHAFOLD3_INFERENCE
        .out
        .iptms
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_iptm_final }

    RUN_ALPHAFOLD3_INFERENCE
        .out
        .ipsaes
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_ipsae_final }

    RUN_ALPHAFOLD3_INFERENCE
        .out
        .chainwise_iptms
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_chainwise_iptm_final }

    RUN_ALPHAFOLD3_INFERENCE
        .out
        .chainwise_ipsaes
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold3";
            [ meta, it[1] ]
        }
        .set { ch_chainwise_ipsae_final }

    emit:
    top_ranked_pdb  = ch_top_ranked_structure // channel: [ meta, /path/to/*.cif ] (common output label)
    pdb             = ch_structure_final      // channel: [ meta, /path/to/*.cif, ...,/path/to/*.cif ] (common output label)
    msa             = ch_msa_final            // channel: [ meta, /path/to/*_alphafold3_msa.tsv ]
    pae             = ch_pae_final             // channel: [ meta, path/to/*_pae.tsv ]
    iptm            = ch_iptm_final            // channel: [ meta, path/to/*_iptm.tsv ]
    ipsae           = ch_ipsae_final           // channel: [ meta, path/to/*_ipsae.tsv ]
    chainwise_iptm  = ch_chainwise_iptm_final  // channel: [ meta, path/to/*_chainwise_iptm.tsv ]
    chainwise_ipsae = ch_chainwise_ipsae_final // channel: [ meta, path/to/*_chainwise_ipsae.tsv ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
