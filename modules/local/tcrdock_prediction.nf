process TCRDOCK_PREDICTION {
    tag "$batch_name"
    label 'process_medium'

    if (params.no_batch_parallel) {
        maxForks 1
    }

    publishDir path: "$params.outdir/$params.mode/prediction/$batch_name", mode: 'copy', saveAs: { filename -> filename.equals('versions.yml') ? null : filename }

    // // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
    //     'biocontainers/YOUR-TOOL-HERE' }"
    // TODO elias: add the container the right way.
    def VERSION = '1.0.0'
    container "tcrdock:${VERSION}"

    input:
    tuple val(batch_name), path(setup_targets_tsv), path(setup_all_tsv_wo_targets), path(setup_all_pdb)

    output:
    tuple val(batch_name), path("user_output_final.tsv"), path("*.pdb"), path("*.npy"), emit: output
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def statement = ''
    
    if (params.use_finetuned_params == true) {
        statement += """
        python /opt/TCRdock/run_prediction.py \
            --targets $setup_targets_tsv \
            --outfile_prefix user_output \
            --data_dir /opt/TCRdock/alphafold_params/ \
            --model_names model_2_ptm_ft4 \
            --model_params_files /opt/TCRdock/alphafold_params/params/tcrpmhc_run4_af_mhc_params_891.pkl \
            $args
        """
    } else {
        statement += """
        python /opt/TCRdock/run_prediction.py \
            --targets $setup_targets_tsv \
            --outfile_prefix user_output \
            --data_dir /opt/TCRdock/alphafold_params/ \
            --model_names model_2_ptm \
            $args
        """
    }
    statement += """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tcrdock: $VERSION
    END_VERSIONS
    """
    return statement

    stub:
    def args = task.ext.args ?: ''
    
    """
    touch user_output_final.tsv
    touch user_output_XXXX.pdb
    touch user_output_XXXX_plddt.npy
    touch user_output_XXXX_predicted_aligned_error.npy
    touch user_output_XXXX_ptm.npy

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tcrdock: $VERSION
    END_VERSIONS
    """
}
