/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_ALPHAFOLD2      } from '../modules/local/run_alphafold2'
include { RUN_ALPHAFOLD2_MSA  } from '../modules/local/run_alphafold2_msa'
include { RUN_ALPHAFOLD2_PRED } from '../modules/local/run_alphafold2_pred'
include { resolveModelPresetByFastaEntities } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

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

workflow ALPHAFOLD2 {

    take:
    ch_samplesheet          // channel: samplesheet read in from --input
    ch_versions             // channel: [ path(versions.yml) ]
    alphafold2_full_dbs     // boolean: Use full databases (otherwise reduced version)
    alphafold2_mode         //  string: Mode to run Alphafold2 in
    alphafold2_model_preset //  string: Specifies the model preset to use for Alphafold2
    uniref30_prefix         //  string: Prefix for uniref30 database files
    ch_alphafold2_params    // channel: path(alphafold2_params)
    ch_bfd                  // channel: path(bfd)
    ch_small_bfd            // channel: path(small_bfd)
    ch_mgnify               // channel: path(mgnify)
    ch_pdb70                // channel: path(pdb70)
    ch_pdb_mmcif            // channel: path(pdb_mmcif)
    ch_pdb_obsolete         // channel: path(pdb_obsolete)
    ch_uniref30             // channel: path(uniref30)
    ch_uniref90             // channel: path(uniref90)
    ch_pdb_seqres           // channel: path(pdb_seqres)
    ch_uniprot              // channel: path(uniprot)

    main:
    ch_pdb            = channel.empty()
    ch_top_ranked_pdb = channel.empty()
    ch_msa            = channel.empty()
    ch_pae            = channel.empty()
    ch_multiqc_report = channel.empty()

    ch_samplesheet
        .map { meta, fasta ->
            def resolved_model_preset = alphafold2_model_preset == 'auto'
                ? resolveModelPresetByFastaEntities(fasta, 'monomer_ptm')
                : alphafold2_model_preset
            [ meta, fasta, resolved_model_preset ]
        }
        .branch { it ->
            multimer: it[2] == 'multimer'
            monomer: it[2] != 'multimer'
        }
        .set { ch_samplesheet_by_preset }

    ch_samplesheet_by_preset.monomer
        .map { meta, fasta, resolved_model_preset ->
            [ meta, resolved_model_preset, fasta.splitFasta(file:true) ]
        }
        .transpose()
        .map { meta, resolved_model_preset, fasta ->
            [ meta, fasta, resolved_model_preset ]
        }
        .mix(ch_samplesheet_by_preset.multimer)
        .set { ch_samplesheet_prepared }

    if (alphafold2_mode == 'standard') {
        //
        // SUBWORKFLOW: Run Alphafold2 standard mode
        //
        RUN_ALPHAFOLD2 (
            ch_samplesheet_prepared,
            alphafold2_full_dbs,
            uniref30_prefix,
            ch_alphafold2_params,
            ch_bfd,
            ch_small_bfd,
            ch_mgnify,
            ch_pdb70,
            ch_pdb_mmcif,
            ch_pdb_obsolete,
            ch_uniref30,
            ch_uniref90,
            ch_pdb_seqres,
            ch_uniprot
        )

        RUN_ALPHAFOLD2
            .out
            .multiqc
            .map { it -> it[1] }
            .toSortedList()
            .map { it ->
                [ [ "model": "alphafold2" ], it.flatten() ]
            }
            .set { ch_multiqc_report }

        ch_pdb            = ch_pdb.mix(RUN_ALPHAFOLD2.out.pdb)
        ch_top_ranked_pdb = ch_top_ranked_pdb.mix(RUN_ALPHAFOLD2.out.top_ranked_pdb)
        ch_msa            = ch_msa.mix(RUN_ALPHAFOLD2.out.msa)
        ch_pae            = ch_pae.mix(RUN_ALPHAFOLD2.out.pae)
        ch_versions       = ch_versions.mix(RUN_ALPHAFOLD2.out.versions)

    } else if (alphafold2_mode == 'split_msa_prediction') {
        //
        // SUBWORKFLOW: Run Alphafold2 split mode, MSA and predicition
        //
        RUN_ALPHAFOLD2_MSA (
            ch_samplesheet_prepared,
            alphafold2_full_dbs,
            uniref30_prefix,
            ch_alphafold2_params,
            ch_bfd,
            ch_small_bfd,
            ch_mgnify,
            ch_pdb70,
            ch_pdb_mmcif,
            ch_pdb_obsolete,
            ch_uniref30,
            ch_uniref90,
            ch_pdb_seqres,
            ch_uniprot
        )
        ch_versions = ch_versions.mix(RUN_ALPHAFOLD2_MSA.out.versions)

        //synchronize
        ch_samplesheet_prepared
            .join(RUN_ALPHAFOLD2_MSA.out.features)
            .map { meta, fasta, resolved_model_preset, features ->
                [ meta, fasta, features, resolved_model_preset ]
            }
            .set { ch_fasta_features }

        RUN_ALPHAFOLD2_PRED (
            ch_fasta_features,
            ch_alphafold2_params,
            ch_bfd,
            ch_small_bfd,
            ch_mgnify,
            ch_pdb70,
            ch_pdb_mmcif,
            ch_pdb_obsolete,
            ch_uniref30,
            ch_uniref90,
            ch_pdb_seqres,
            ch_uniprot
        )

        RUN_ALPHAFOLD2_PRED
            .out
            .multiqc
            .map { it -> it[1] }
            .toSortedList()
            .map { it ->
                [ [ "model": "alphafold2" ], it.flatten() ]
            }
            .set { ch_multiqc_report }

        ch_top_ranked_pdb = ch_top_ranked_pdb.mix(RUN_ALPHAFOLD2_PRED.out.top_ranked_pdb)
        ch_pdb            = ch_pdb.mix(RUN_ALPHAFOLD2_PRED.out.pdb)
        ch_msa            = ch_msa.mix(RUN_ALPHAFOLD2_PRED.out.msa)
        ch_pae            = ch_pae.mix(RUN_ALPHAFOLD2_PRED.out.pae)
        ch_versions       = ch_versions.mix(RUN_ALPHAFOLD2_PRED.out.versions)
    }

    ch_pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold2";
            def files = (it[1] instanceof List) ? it[1] : [ it[1] ]
            [ meta, files ]
        }
        .set { ch_pdb_final }

    ch_msa
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold2";
            [ meta, it[1] ]
        }
        .set { ch_msa_final }

    ch_pae
        .map { it ->
            def meta = it[0].clone();
            meta.model = "alphafold2";
            [ meta, it[1] ]
        }
        .set { ch_pae_final }

    ch_top_ranked_pdb_final = ch_top_ranked_pdb
                                .map { it ->
                                    def meta = it[0].clone();
                                    meta.model = "alphafold2";
                                    [ meta, it[1] ]
                                }

    emit:
    top_ranked_pdb = ch_top_ranked_pdb_final // channel: [ meta, /path/to/*.pdb ]
    pdb            = ch_pdb_final            // channel: [ meta, /path/to/*.pdb ]
    msa            = ch_msa_final            // channel: [ meta, /path/to/*.pdb, /path/to/*_coverage.png ]  // Would prefer channel: [ meta, /path/to/*_msa.tsv ]
    pae            = ch_pae_final            // channel: [ meta, /path/to/*_0_pae.tsv]
    multiqc_report = ch_multiqc_report       // channel: /path/to/multiqc_report.html
    versions       = ch_versions             // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
