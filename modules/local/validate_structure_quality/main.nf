process VALIDATE_STRUCTURE_QUALITY {
    tag "$meta.id"
    label 'process_single'

    conda "python=3.10 biopython numpy"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/biopython:1.81' :
        'quay.io/biocontainers/biopython:1.81' }"

    input:
    tuple val(meta), path(pdb_file)

    output:
    tuple val(meta), path("${meta.id}_quality_report.json"), emit: report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: '--plddt-min 0.4 --plddt-target 0.7'

    """
    compare_structures_fuzzy.py validate ${pdb_file} ${args} --output ${meta.id}_quality_report.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        biopython: \$(python -c "import Bio; print(Bio.__version__)")
    END_VERSIONS
    """

    stub:
    """
    echo '{"status": "PASS", "pdb_file": "'${pdb_file}'", "avg_plddt": 0.75}' > ${meta.id}_quality_report.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        biopython: \$(python -c "import Bio; print(Bio.__version__)")
    END_VERSIONS
    """
}
