/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_ROSETTAFOLD_ALL_ATOM } from '../modules/local/run_rosettafold_all_atom'
include { FASTA2YAML               } from '../modules/local/fasta2yaml'

include { modeChannel              } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

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
    uniref30_prefix         //  string: Prefix for uniref30 database files
    ch_bfd                  // channel: path(bfd)
    ch_uniref30             // channel: path(uniref30)
    ch_pdb100               // channel: path(pdb100)
    ch_rfaa_paper_weights   // channel: path(rfaa_paper_weightsch_dummy_file           // channel: path(NO_file)

    main:

    ch_samplesheet.branch { it ->
        fasta: it[1].extension == "fasta" || it[1].extension == "fa"
        yaml: it[1].extension == "yaml"
    }.set{ch_input}

    FASTA2YAML(
        ch_input.fasta
    )

    ch_input.yaml.map { it ->
        [it[0], it[1], []]
    }
    .mix(FASTA2YAML.out.yaml.join(FASTA2YAML.out.fasta))
    .set{ch_rosetta_all_atom_in}

    RUN_ROSETTAFOLD_ALL_ATOM (
        ch_rosetta_all_atom_in.map { it -> [it[0], it[1]] },
        uniref30_prefix,
        ch_bfd,
        ch_uniref30,
        ch_pdb100,
        ch_rfaa_paper_weights,
        ch_rosetta_all_atom_in.map { it -> it[2] }
    )
    ch_versions = ch_versions.mix(RUN_ROSETTAFOLD_ALL_ATOM.out.versions)

    modeChannel(RUN_ROSETTAFOLD_ALL_ATOM.out.pdb, "rosettafold_all_atom", true).set { ch_pdb_final }
    modeChannel(RUN_ROSETTAFOLD_ALL_ATOM.out.msa, "rosettafold_all_atom").set { ch_msa_final }
    modeChannel(RUN_ROSETTAFOLD_ALL_ATOM.out.pae, "rosettafold_all_atom").set { ch_pae_final }

    emit:
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
