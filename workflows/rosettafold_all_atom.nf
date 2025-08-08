/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_ROSETTAFOLD_ALL_ATOM } from '../modules/local/run_rosettafold_all_atom'
include { FASTA2YAML } from '../modules/local/data_convertor/fasta2yaml'
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

workflow ROSETTAFOLD_ALL_ATOM {

    take:
    ch_samplesheet          // channel: samplesheet read in from --input
    ch_versions             // channel: [ path(versions.yml) ]
    ch_bfd                  // channel: path(bfd)
    ch_uniref30             // channel: path(uniref30)
    ch_pdb100               // channel: path(pdb100)
    ch_rfaa_paper_weights   // channel: path(rfaa_paper_weightsch_dummy_file           // channel: path(NO_file)

    main:
    ch_multiqc_files  = Channel.empty()
    ch_top_ranked_pdb = Channel.empty()
    ch_multiqc_report = Channel.empty()

    ch_samplesheet.branch {
        fasta: it[1].extension == "fasta" || it[1].extension == "fa"
        yaml: it[1].extension == "yaml"
    }.set{ch_input}

    FASTA2YAML(
        ch_input.fasta
    )

    ch_input.yaml.map{[it[0], it[1], []]}
    .mix(FASTA2YAML.out.yaml.join(FASTA2YAML.out.fasta))
    .set{ch_rosetta_all_atom_in}

    RUN_ROSETTAFOLD_ALL_ATOM (
        ch_rosetta_all_atom_in.map{[it[0], it[1]]},
        ch_bfd,
        ch_uniref30,
        ch_pdb100,
        ch_rfaa_paper_weights,
        ch_rosetta_all_atom_in.map{it[2]}
    )
    ch_versions = ch_versions.mix(RUN_ROSETTAFOLD_ALL_ATOM.out.versions)

    RUN_ROSETTAFOLD_ALL_ATOM
        .out
        .multiqc
        .map { it[1] }
        .toSortedList()
        .map { [ [ "model": "rosettafold_all_atom" ], it.flatten() ] }
        .set { ch_multiqc_report }

    RUN_ROSETTAFOLD_ALL_ATOM
        .out
        .pdb
        .map{
            meta = it[0].clone();
            meta.model = "rosettafold_all_atom";
            [meta, it[1]]
        }.set { ch_pdb_final }

    emit:
    pdb            = ch_pdb_final // channel: [ id, /path/to/*.pdb ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
