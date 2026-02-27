process MMSEQS_COLABFOLDSEARCH {
    tag "$meta.id"
    label 'process_high_memory'
    label 'process_high'

    container "/home/z3545907/mmseqs_colabfoldsearch.sif"

    input:
    tuple val(meta), path(fasta)
    path ('db/*')
    path ('db/*')
    val colabfold_enable_gpu_search

    output:
    tuple val(meta), path("**.a3m"), emit: a3m
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local MMSEQS_COLABFOLDSEARCH module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''

    """
    GPU_ARG=""
    if [ "${colabfold_enable_gpu_search}" == "1" ]; then
        GPU_ARG="--gpu 1"
    fi
    colabfold_search \\
        $args \\
        \${GPU_ARG} \\
        --threads $task.cpus ${fasta} \\
        ./db \\
        --af3-json \\
        "results/"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold_search: \$(pip list | grep "^colabfold" | awk '{print \$2}' 2>/dev/null || echo "unknown")
        mmseqs: \$(mmseqs version)
    END_VERSIONS
    """

    stub:
    """
    mkdir results
    touch results/${meta.id}.a3m

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold_search: \$(pip list | grep "^colabfold" | awk '{print \$2}' 2>/dev/null || echo "unknown")
        mmseqs: \$(mmseqs version)
    END_VERSIONS
    """
}
