/*
 * Extract metrics from ESMFold outputs
 */
process EXTRACT_METRICS_ESMFOLD {
    tag "$meta.id"
    label 'process_single'

    container "nf-core/proteinfold_esmfold:2.0.0"

    input:
    tuple val(meta), path(raw)

    output:
    tuple val(meta), path("${meta.id}_plddt.tsv"), emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    extract_metrics.py --name ${meta.id} \\
        --structs ${raw}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_plddt.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
