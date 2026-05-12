process MMSEQS_COLABFOLDSEARCH {
    tag "$meta.id"
    label 'process_high_memory'
    label 'process_high'

    container "nf-core/proteinfold_mmseqs_colabfoldsearch:2.0.0"

    input:
    tuple val(meta), path(fasta)
    path ('db/*')
    path ('uniref30/*')

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
    for f in uniref30/*; do
        if [ ! -e "db/\$(basename \$f)" ]; then
            ln -sf \$(realpath \$f) db/\$(basename \$f)
        else
            echo "WARNING: skipping uniref30/\$(basename \$f) -- already present from colabfold_db" >&2
        fi
    done

    colabfold_search \\
        $args \\
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
