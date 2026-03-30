/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_ESMFOLD               } from '../modules/local/run_esmfold'
include { MULTIFASTA_TO_SINGLEFASTA } from '../modules/local/multifasta_to_singlefasta'
include { countMolecularEntitiesInFasta } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

include { modeChannel               } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

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

workflow ESMFOLD {

    take:
    ch_samplesheet    // channel: samplesheet read in from --input
    ch_versions       // channel: [ path(versions.yml) ]
    ch_esmfold_params // directory: /path/to/esmfold/params/
    ch_num_recycles   // int: Number of recycles for esmfold

    main:
    //
    // MODULE: Run esmfold
    //
    ch_samplesheet
        .map { meta, fasta ->
            [ meta, fasta, countMolecularEntitiesInFasta(fasta) ]
        }
        .branch { it ->
            multimer: it[2] > 1
            monomer: it[2] <= 1
        }
        .set { ch_input_by_entity_count }

    MULTIFASTA_TO_SINGLEFASTA(
        ch_input_by_entity_count.multimer.map { meta, fasta, _entity_count ->
            [ meta, fasta ]
        }
    )
    ch_versions = ch_versions.mix(MULTIFASTA_TO_SINGLEFASTA.out.versions)
    RUN_ESMFOLD(
        ch_input_by_entity_count.monomer
            .map { meta, fasta, _entity_count ->
                [ meta, fasta ]
            }
            .mix(MULTIFASTA_TO_SINGLEFASTA.out.input_fasta),
        ch_esmfold_params,
        ch_num_recycles
    )
    ch_versions = ch_versions.mix(RUN_ESMFOLD.out.versions)

    RUN_ESMFOLD
        .out
        .multiqc
        .map { it -> it[1] }
        .toSortedList()
        .map { it ->
            [ [ "model": "esmfold"], it.flatten() ]
        }
        .set { ch_multiqc_report  }

    modeChannel(RUN_ESMFOLD.out.pdb, "esmfold").set { ch_pdb_final }

    emit:
    pdb            = ch_pdb_final      // channel: [ id, /path/to/*.pdb ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
