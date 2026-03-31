/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_HELIXFOLD3 } from '../modules/local/run_helixfold3'
include { FASTA2JSON     } from '../modules/local/fasta2json'

include { modeChannel    } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

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

workflow HELIXFOLD3 {

    take:
    ch_samplesheet
    ch_versions                    // channel: [ path(versions.yml) ]
    uniref30_prefix                //  string: Prefix for uniref30 database files
    ch_helixfold3_uniclust30       // channel: path(uniclust30)
    ch_helixfold3_ccd_preprocessed // channel: path(ccd_preprocessed)
    ch_helixfold3_rfam             // channel: path(rfam)
    ch_helixfold3_bfd              // channel: path(bfd)
    ch_helixfold3_small_bfd        // channel: path(small_bfd)
    ch_helixfold3_uniprot          // channel: path(uniprot)
    ch_helixfold3_pdb_seqres       // channel: path(pdb_seqres)
    ch_helixfold3_uniref90         // channel: path(uniref90)
    ch_helixfold3_mgnify           // channel: path(mgnify)
    ch_helixfold3_mmcif_files      // channel: path(pdb_mmcif)
    ch_helixfold3_obsolete         // channel: path(pdb_obsolete)
    ch_helixfold3_init_models      // channel: path(init_models)
    ch_helixfold3_maxit_src        // channel: path(maxit_src)

    main:
    ch_pdb            = channel.empty()
    ch_top_ranked_pdb = channel.empty()

    //
    // SUBWORKFLOW: Run helixfold3
    //
    ch_samplesheet.branch { it ->
        fasta: it[1].extension == "fasta" || it[1].extension == "fa"
        json: it[1].extension == "json"
    }.set { ch_input }

    FASTA2JSON(ch_input.fasta)

    RUN_HELIXFOLD3 (
        ch_input.json.mix(FASTA2JSON.out.json),
        uniref30_prefix,
        ch_helixfold3_uniclust30,
        ch_helixfold3_ccd_preprocessed,
        ch_helixfold3_rfam,
        ch_helixfold3_bfd,
        ch_helixfold3_small_bfd,
        ch_helixfold3_uniprot,
        ch_helixfold3_pdb_seqres,
        ch_helixfold3_uniref90,
        ch_helixfold3_mgnify,
        ch_helixfold3_mmcif_files,
        ch_helixfold3_obsolete,
        ch_helixfold3_init_models,
        ch_helixfold3_maxit_src
    )

    ch_pdb      = ch_pdb.mix(RUN_HELIXFOLD3.out.pdb)
    ch_versions = ch_versions.mix(RUN_HELIXFOLD3.out.versions)

    RUN_HELIXFOLD3
        .out
        .top_ranked_pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "helixfold3";
            [ meta, it[1] ]
        }
        .set { ch_top_ranked_pdb }

    RUN_HELIXFOLD3
        .out
        .pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "helixfold3";
            def files = (it[1] instanceof List) ? it[1] : [ it[1] ]
            [ meta, files ]
        }
        .set { ch_pdb_final }

    modeChannel(RUN_HELIXFOLD3.out.msa, "helixfold3").set { ch_msa_final }
    modeChannel(RUN_HELIXFOLD3.out.pae, "helixfold3").set { ch_pae_final }

    emit:
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ meta, /path/to/*.pdb ]
    pdb            = ch_pdb_final      // channel: [ id, /path/to/*.pdb ]
    msa            = ch_msa_final      // channel: [ id, /path/to/*_msa.tsv ]
    pae            = ch_pae_final      // channel: [ id, /path/to/*_pae.tsv ]
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
