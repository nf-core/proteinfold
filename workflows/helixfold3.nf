/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_HELIXFOLD3 } from '../modules/local/run_helixfold3'
include { FASTA2JSON } from '../modules/local/data_convertor/fasta2json'

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
    ch_versions             // channel: [ path(versions.yml) ]
    ch_helixfold3_uniclust30
    ch_helixfold3_ccd_preprocessed
    ch_helixfold3_rfam
    ch_helixfold3_bfd
    ch_helixfold3_small_bfd
    ch_helixfold3_uniprot
    ch_helixfold3_pdb_seqres
    ch_helixfold3_uniref90
    ch_helixfold3_mgnify
    ch_helixfold3_mmcif_files
    ch_helixfold3_obsolete
    ch_helixfold3_init_models
    ch_helixfold3_maxit_src

    main:
    ch_multiqc_files  = Channel.empty()
    ch_pdb            = Channel.empty()
    ch_top_ranked_pdb = Channel.empty()
    ch_multiqc_report = Channel.empty()

    //
    // SUBWORKFLOW: Run helixfold3
    //
    ch_samplesheet.branch {
        fasta: it[1].extension == "fasta" || it[1].extension == "fa"
        json: it[1].extension == "json"
    }.set{ch_input}

    FASTA2JSON(
        ch_input.fasta
    )

    RUN_HELIXFOLD3 (
        ch_input.json.mix(FASTA2JSON.out.json),
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

    RUN_HELIXFOLD3
        .out
        .multiqc
        .map { it[1] }
        .toSortedList()
        .map { [ [ "model": "helixfold3" ], it.flatten() ] }
        .set { ch_multiqc_report }

    ch_pdb            = ch_pdb.mix(RUN_HELIXFOLD3.out.pdb)
    ch_versions       = ch_versions.mix(RUN_HELIXFOLD3.out.versions)

    RUN_HELIXFOLD3.out.top_ranked_pdb
    .map{
        meta = it[0].clone();
        meta.model = "helixfold3";
        [meta, it[1]]
    }
    .set { ch_top_ranked_pdb }

    ch_pdb
    .map{
        meta = it[0].clone();
        meta.model = "helixfold3";
        [meta, it[1]]
    }
    .set { ch_pdb_final }

    emit:
    top_ranked_pdb = ch_top_ranked_pdb
    pdb            = ch_pdb_final // channel: [ id, /path/to/*.pdb ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
