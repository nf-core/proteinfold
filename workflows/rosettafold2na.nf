/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { ROSETTAFOLD2NA_FASTA } from '../modules/local/rosettafold2na_fasta'
include { RUN_ROSETTAFOLD2NA   } from '../modules/local/run_rosettafold2na'

include { modeChannel          } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ROSETTAFOLD2NA {

    take:
    ch_samplesheet            // channel: samplesheet read in from --input
    ch_versions               // channel: [ path(versions.yml) ]
    ch_bfd                    // channel: path(bfd)
    ch_uniref30               // channel: path(uniref30)
    ch_pdb100                 // channel: path(pdb100)
    ch_rna                    // channel: path(rna)
    ch_rosettafold2na_weights // channel: path(rosettafold2na_weights)

    main:

    ROSETTAFOLD2NA_FASTA(
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(ROSETTAFOLD2NA_FASTA.out.versions)

    RUN_ROSETTAFOLD2NA (
        ROSETTAFOLD2NA_FASTA.out.rf2na_input,
        ch_bfd,
        ch_uniref30,
        ch_pdb100,
        ch_rna,
        ch_rosettafold2na_weights
    )
    ch_versions = ch_versions.mix(RUN_ROSETTAFOLD2NA.out.versions)

    modeChannel(RUN_ROSETTAFOLD2NA.out.pdb, "rosettafold2na").set { ch_pdb_final }
    modeChannel(RUN_ROSETTAFOLD2NA.out.pae, "rosettafold2na").set { ch_pae_final }
    modeChannel(RUN_ROSETTAFOLD2NA.out.msa, "rosettafold2na").set { ch_msa_final }

    emit:
    pdb            = ch_pdb_final      // channel: [ id, /path/to/*.pdb ]
    pae            = ch_pae_final      // channel: [ id, /path/to/*_pae.tsv ]
    msa            = ch_msa_final      // channel: [ id, /path/to/*_msa.tsv ]
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
