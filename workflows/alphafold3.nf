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

include { modeChannel                       } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

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
    ch_alphafold3_params // channel: path(alphafold3_params)
    ch_small_bfd         // channel: path(small_bfd)
    ch_mgnify            // channel: path(mgnify)
    ch_mmcif_files       // channel: path(mmcif_files)
    ch_uniref90          // channel: path(uniref90)
    ch_pdb_seqres        // channel: path(pdb_seqres)
    ch_uniprot           // channel: path(uniprot)
    ch_nt_rna            // channel: path(ntrna)
    ch_rfam              // channel: path(rfam)
    ch_rnacentral        // channel: path(rnacentral)

    main:
    ch_pdb_final      = channel.empty()
    ch_top_ranked_pdb = channel.empty()
    ch_msa_final      = channel.empty()

    ch_samplesheet
        .branch { it ->
            fasta: it[1].extension == "fasta" || it[1].extension == "fa"
            json: it[1].extension == "json"
    }.set { ch_input_by_ext }

    FASTA_TO_ALPHAFOLD3_JSON(ch_input_by_ext.fasta)
    ch_versions = ch_versions.mix(FASTA_TO_ALPHAFOLD3_JSON.out.versions)

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
        ch_uniprot,
        ch_nt_rna,
        ch_rfam,
        ch_rnacentral
    )
    ch_versions = ch_versions.mix(RUN_ALPHAFOLD3_DATAPIPELINE.out.versions)

    //
    // MODULE: Run AlphaFold3 inference using pre-computed data JSON
    //
    RUN_ALPHAFOLD3_INFERENCE (
        RUN_ALPHAFOLD3_DATAPIPELINE.out.data_json,
        ch_alphafold3_params
    )
    ch_versions = ch_versions.mix(RUN_ALPHAFOLD3_INFERENCE.out.versions)

    modeChannel(MMCIF2PDB_MODELS.out.pdb, "alphafold3", true).set { ch_pdb_final }

    // Convert top ranked mmcif to pdb
    MMCIF2PDB_TOP_RANKED (
        RUN_ALPHAFOLD3
            .out
            .top_ranked_cif
    )
    ch_versions = ch_versions.mix(MMCIF2PDB_TOP_RANKED.out.versions)

    modeChannel(MMCIF2PDB_TOP_RANKED.out.pdb, "alphafold3").set { ch_top_ranked_pdb }

    // Prepare msa input
    modeChannel(RUN_ALPHAFOLD3.out.msa, "alphafold3").set { ch_msa_final }

    // Prepare dummy pae input
    modeChannel(RUN_ALPHAFOLD3.out.pae, "alphafold3").set { ch_pae_final }

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
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ id, /path/to/*.pdb ]
    pdb            = ch_pdb_final      // channel: [ meta, /path/to/*.pdb, ...,/path/to/*.pdb ]
    msa            = ch_msa_final      // channel: [ meta, /path/to/*.pdb, /path/to/*_coverage.png ]
    pae            = ch_pae_final      // channel: [ meta, path/to/*_pae.tsv ]
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
