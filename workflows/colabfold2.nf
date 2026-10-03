/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//

include { COLABFOLD2_INFERENCE as ALPHAFOLD3      } from '../modules/local/colabfold2_inference'
include { COLABFOLD2_INFERENCE as BOLTZ2          } from '../modules/local/colabfold2_inference'
include { COLABFOLD2_INFERENCE as OPENFOLD3       } from '../modules/local/colabfold2_inference'
include { COLABFOLD2_INFERENCE as OPENBIND0       } from '../modules/local/colabfold2_inference'
include { COLABFOLD2_INFERENCE as PROTEINX2       } from '../modules/local/colabfold2_inference'
include { COLABFOLD2_INFERENCE as CHAI1           } from '../modules/local/colabfold2_inference'
include { COLABFOLD2_INFERENCE as INTELLIFOLD2    } from '../modules/local/colabfold2_inference'
include { COLABFOLD2_INFERENCE as OPENDDE         } from '../modules/local/colabfold2_inference'
include { COLABFOLD2_INFERENCE as ROSETTAFOLD3    } from '../modules/local/colabfold2_inference'
include { COLABFOLD2_INFERENCE as ESMFOLD2        } from '../modules/local/colabfold2_inference'

include { ALPHAFOLD3_JSON_TO_COLABFOLD_FASTA } from '../modules/local/alphafold3_json_to_colabfold_fasta'
include { MERGE_ALPHAFOLD3_MSA               } from '../modules/local/merge_alphafold3_msa'
include { MMSEQS_COLABFOLDSEARCH              } from '../modules/local/mmseqs_colabfoldsearch'
include { collectMultiqcMetrics; modeChannel   } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

workflow COLABFOLD2 {

    take:
    ch_samplesheet  // channel: samplesheet read in from --input
    ch_params_path  // channel: path(colabfold2_params_path, the weights/data dir root)
    model_type      // string: explicit upstream AF3-family model name
    use_esm         // boolean: select the ESM-C language-model path for ESMFold2
    public_mode     // string: public mode token used for output publication
    num_recycles    // int: Number of recycles for the selected backend
    ch_colabfold_db // channel: path(colabfold_db)
    ch_uniref30     // channel: path(uniref30)

    main:
    // Mode token -> inference process alias; the three esmfold2 selections share the ESMFOLD2 alias.
    def COLABFOLD2_BACKENDS = [
        'alphafold3'      : 'ALPHAFOLD3',
        'boltz2'          : 'BOLTZ2',
        'openfold3'       : 'OPENFOLD3',
        'openbind0'       : 'OPENBIND0',
        'protenix2'       : 'PROTEINX2',
        'chai1'           : 'CHAI1',
        'intellifold2'    : 'INTELLIFOLD2',
        'opendde'         : 'OPENDDE',
        'rosettafold3'    : 'ROSETTAFOLD3',
        'esmfold2'        : 'ESMFOLD2',
        'esmfold2_lm300m' : 'ESMFOLD2',
        'esmfold2_lm600m' : 'ESMFOLD2'
    ]

    ch_msa_input = null

    ch_samplesheet
        .map { meta, input ->
            def extension = input.extension.toLowerCase()
            if (!(extension in ['fa', 'faa', 'fasta', 'json'])) {
                error("ColabFold2 input for sample '${meta.id}' must be FASTA or AlphaFold3 JSON; received '${input.name}'.")
            }
            [meta, input]
        }
        .branch { meta, input ->
            json:  input.extension.toLowerCase() == 'json'
            fasta: true
        }
        .set { ch_input_by_ext }

    if (params.use_msa_server) {
        // colabfold_batch reads AF3 JSON directly and preserves its non-protein metadata.
        ch_msa_input = ch_input_by_ext.fasta.mix(ch_input_by_ext.json)
    } else {
        // colabfold_search needs FASTA: extract protein queries, search, then merge the MSAs back into the original JSON.
        ch_input_by_ext.json
            .map { meta, input_json ->
                def search_meta = meta.clone()
                search_meta.colabfold2_json_input = true
                [search_meta, input_json]
            }
            .set { ch_json_for_search }

        ch_input_by_ext.json
            .map { meta, input_json -> [meta.id, input_json] }
            .set { ch_json_templates }

        ALPHAFOLD3_JSON_TO_COLABFOLD_FASTA(ch_json_for_search)

        ch_search_input = ch_input_by_ext.fasta.mix(ALPHAFOLD3_JSON_TO_COLABFOLD_FASTA.out.query_fasta)
        MMSEQS_COLABFOLDSEARCH(
            ch_search_input,
            ch_colabfold_db,
            ch_uniref30
        )

        MMSEQS_COLABFOLDSEARCH.out.json
            .branch { meta, msa_json ->
                json:  meta.colabfold2_json_input == true
                fasta: true
            }
            .set { ch_search_result }

        ch_search_result.json
            .map { meta, msa_json -> [meta.id, meta, msa_json] }
            .join(ch_json_templates)
            .map { id, meta, msa_json, original_json ->
                def clean_meta = meta.clone()
                clean_meta.remove('colabfold2_json_input')
                [clean_meta, msa_json, original_json]
            }
            .set { ch_json_merge_input }

        MERGE_ALPHAFOLD3_MSA(ch_json_merge_input)
        ch_msa_input = ch_search_result.fasta.mix(MERGE_ALPHAFOLD3_MSA.out.json)
    }

    //
    // MODULE: Run inference on the process belonging to the selected backend
    //
    // The explicit model name selects the upstream backend; aliases identify the
    // selected backend in task names and reports.
    def backend_process = COLABFOLD2_BACKENDS[model_type]
    if (backend_process == null) {
        error("ColabFold2 backend '${model_type}' is not wired to an inference process. Wired backends: ${COLABFOLD2_BACKENDS.keySet().join(', ')}.")
    }

    // Static dispatch: the repo's Nextflow linter cannot parse dynamic process invocation.
    if (backend_process == 'ALPHAFOLD3') {
        ALPHAFOLD3(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = ALPHAFOLD3.out
    } else if (backend_process == 'BOLTZ2') {
        BOLTZ2(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = BOLTZ2.out
    } else if (backend_process == 'OPENFOLD3') {
        OPENFOLD3(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = OPENFOLD3.out
    } else if (backend_process == 'OPENBIND0') {
        OPENBIND0(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = OPENBIND0.out
    } else if (backend_process == 'PROTEINX2') {
        PROTEINX2(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = PROTEINX2.out
    } else if (backend_process == 'CHAI1') {
        CHAI1(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = CHAI1.out
    } else if (backend_process == 'INTELLIFOLD2') {
        INTELLIFOLD2(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = INTELLIFOLD2.out
    } else if (backend_process == 'OPENDDE') {
        OPENDDE(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = OPENDDE.out
    } else if (backend_process == 'ROSETTAFOLD3') {
        ROSETTAFOLD3(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = ROSETTAFOLD3.out
    } else if (backend_process == 'ESMFOLD2') {
        ESMFOLD2(ch_msa_input, model_type, use_esm, public_mode, num_recycles, ch_params_path)
        ch_batch = ESMFOLD2.out
    } else {
        error("ColabFold2 backend '${model_type}' resolved to unknown process '${backend_process}'.")
    }

    ch_batch.top_ranked_structure
        .map { meta, structure ->
            def report_meta = meta.clone()
            report_meta.model = 'colabfold2'
            [report_meta, structure]
        }
        .set { ch_top_ranked_structure }

    ch_batch.structures
        .map { meta, structures ->
            def report_meta = meta.clone()
            report_meta.model = 'colabfold2'
            def ranked = (structures instanceof List ? structures : [structures]).sort { structure ->
                def matcher = structure.name =~ /_rank_(\d+)_/
                matcher.find() ? matcher.group(1).toInteger() : Integer.MAX_VALUE
            }
            [report_meta, ranked]
        }
        .set { ch_structures }

    // Reports use the shared colabfold2 model name while task names identify the selected backend.
    modeChannel(ch_batch.msa, 'colabfold2').set { ch_msa }
    modeChannel(ch_batch.pae, 'colabfold2').set { ch_pae }
    modeChannel(ch_batch.ptms, 'colabfold2').set { ch_ptm }
    modeChannel(ch_batch.iptms, 'colabfold2').set { ch_iptm }
    modeChannel(ch_batch.ipsaes, 'colabfold2').set { ch_ipsae }
    modeChannel(ch_batch.chainwise_iptms, 'colabfold2').set { ch_chainwise_iptm }
    modeChannel(ch_batch.chainwise_ipsaes, 'colabfold2').set { ch_chainwise_ipsae }
    modeChannel(ch_batch.confidence, 'colabfold2').set { ch_confidence }

    ch_multiqc_metrics = collectMultiqcMetrics('colabfold2', [
        [ 'plddt', ch_batch.plddt ],
        [ 'msa',   ch_batch.msa ],
        [ 'ptm',   ch_batch.ptms ],
        [ 'iptm',  ch_batch.iptms ]
    ])

    emit:
    top_ranked_pdb  = ch_top_ranked_structure
    pdb             = ch_structures
    msa             = ch_msa
    pae             = ch_pae
    ptm             = ch_ptm
    iptm            = ch_iptm
    ipsae           = ch_ipsae
    chainwise_iptm  = ch_chainwise_iptm
    chainwise_ipsae = ch_chainwise_ipsae
    confidence      = ch_confidence
    multiqc_metrics = ch_multiqc_metrics
}
