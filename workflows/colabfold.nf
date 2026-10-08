/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { COLABFOLD_BATCH        } from '../modules/local/colabfold_batch'
include { MMSEQS_COLABFOLDSEARCH } from '../modules/local/mmseqs_colabfoldsearch'
include { MMSEQS_COLABFOLDSEARCH_BATCH } from '../modules/local/mmseqs_colabfoldsearch'
include { MULTIFASTA_TO_CSV      } from '../modules/local/multifasta_to_csv'

include { modeChannel            } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { collectMultiqcMetrics  } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

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

workflow COLABFOLD {

    take:
    ch_samplesheet          // channel: samplesheet read in from --input
    ch_colabfold_params    // channel: path(colabfold_params)
    ch_colabfold_db        // channel: path(colabfold_db)
    ch_uniref30            // channel: path(uniref30)
    num_recycles           // int: Number of recycles for colabfold
    msa_batch_size        // int: number of samples processed together during MSA search

    main:
    ch_multiqc_metrics = channel.empty()

    ch_byo_msa = ch_samplesheet
        .filter { meta, fasta -> meta.msa }
        .map { meta, fasta ->
            log.info "Using samplesheet MSA for ${meta.id}; bypassing ColabFold MSA generation"
            def meta_without_msa = meta.clone()
            def msa = meta_without_msa.remove('msa')
            [meta_without_msa, msa]
        }

    ch_generated_input = ch_samplesheet
        .filter { meta, fasta -> !meta.msa }

    ch_colabfold_input = ch_byo_msa

    MULTIFASTA_TO_CSV(
        ch_generated_input
    )

    if (params.use_msa_server) {
        ch_colabfold_input = ch_colabfold_input.mix(
            MULTIFASTA_TO_CSV.out.input_csv
        )
    } else {
        def batch_size = msa_batch_size instanceof Number ? msa_batch_size : msa_batch_size.toString().toInteger()
        if (batch_size == 0 || batch_size < -1) {
            error("MSA batch size must be -1 or a positive integer, got ${batch_size}")
        }
        if (batch_size == 1) {
            MMSEQS_COLABFOLDSEARCH (
                MULTIFASTA_TO_CSV.out.input_csv,
                ch_colabfold_db,
                ch_uniref30
            )
            ch_generated_msa = MMSEQS_COLABFOLDSEARCH.out.a3m
        } else {
            ch_batches = MULTIFASTA_TO_CSV.out.input_csv
                .map { meta, csv -> [meta.id, meta, csv] }
                .collect(flat: false)
                .flatMap { rows ->
                    def sorted = rows.sort { a, b -> a[0] <=> b[0] }
                    def ids = sorted.collect { row -> row[0] }
                    if (ids.toSet().size() != ids.size()) error("Duplicate sample IDs are not allowed")
                    def effective_batch_size = batch_size == -1 ? Math.max(1, sorted.size()) : batch_size
                    sorted.collate(effective_batch_size).collect { batch ->
                        [batch.collect { it[1] }, batch.collect { it[2] }]
                    }
                }
            MMSEQS_COLABFOLDSEARCH_BATCH(ch_batches, ch_colabfold_db, ch_uniref30)
            ch_generated_msa = MMSEQS_COLABFOLDSEARCH_BATCH.out.a3m
                .flatMap { batch_meta, files ->
                    def batch_files = files instanceof List ? files : [files]
                    batch_files.collect { file ->
                        def sample_id = file.name.endsWith('.a3m') ? file.name[0..-5] : file.name
                        def sample = batch_meta.find { meta -> meta.get('id') == sample_id }
                        if (sample == null) error("MMseqs batch output ${file.name} does not match input samples ${batch_meta*.id}")
                        [sample, file]
                    }
                }
        }
        ch_colabfold_input = ch_colabfold_input.mix(ch_generated_msa)
    }

    COLABFOLD_BATCH(
        ch_colabfold_input
            .combine(ch_colabfold_params),
        num_recycles
    )

    COLABFOLD_BATCH
        .out
        .top_ranked_pdb
        .map { it ->
            def meta_clone = it[0].clone();
            meta_clone.model = "colabfold";
            [ meta_clone, it[1] ]
        }
        .set { ch_top_ranked_pdb }

    COLABFOLD_BATCH
        .out
        .pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "colabfold";
            def files = (it[1] instanceof List) ? it[1] : [ it[1] ]
            [ meta, files ]
        }
        .set { ch_pdb_final }

    modeChannel(COLABFOLD_BATCH.out.msa, "colabfold").set { ch_msa_final }
    modeChannel(COLABFOLD_BATCH.out.pae, "colabfold").set { ch_pae_final }
    modeChannel(COLABFOLD_BATCH.out.iptms, "colabfold").set { ch_iptm_final }
    modeChannel(COLABFOLD_BATCH.out.ipsaes, "colabfold").set { ch_ipsae_final }
    modeChannel(COLABFOLD_BATCH.out.chainwise_iptms, "colabfold").set { ch_chainwise_iptm_final }
    modeChannel(COLABFOLD_BATCH.out.chainwise_ipsaes, "colabfold").set { ch_chainwise_ipsae_final }

    // Hand MultiQC every metric this model actually produces, not just pLDDT.
    ch_multiqc_metrics = collectMultiqcMetrics("colabfold", [
        [ 'plddt', COLABFOLD_BATCH.out.plddt ],
        [ 'msa',   COLABFOLD_BATCH.out.msa ],
        [ 'ptms',  COLABFOLD_BATCH.out.ptms ],
        [ 'iptms', COLABFOLD_BATCH.out.iptms ]
    ])

    emit:
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ meta, /path/to/*.pdb ]
    pdb            = ch_pdb_final      // channel: [ id, /path/to/*.pdb ]
    msa            = ch_msa_final      // channel: [ meta, /path/to/*.pdb, /path/to/*_coverage.png ]
    pae            = ch_pae_final      // channel: [ id, /path/to/*_pae.tsv ]
    iptm           = ch_iptm_final     // channel: [ id, /path/to/*_iptm.tsv ]
    ipsae          = ch_ipsae_final    // channel: [ id, /path/to/*_ipsae.tsv ]
    chainwise_iptm = ch_chainwise_iptm_final // channel: [ id, /path/to/*_chainwise_iptm.tsv ]
    chainwise_ipsae = ch_chainwise_ipsae_final // channel: [ id, /path/to/*_chainwise_ipsae.tsv ]
    multiqc_metrics = ch_multiqc_metrics // channel: [ [id:..., model:...], [metric tsvs] ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
