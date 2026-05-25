process FASTA2YAML {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path ("*.yaml"), emit: yaml
    tuple val(meta), path ("out_fasta/*.fasta"), emit: fasta
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //g'"), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    fasta_to_yaml.py ${fasta} ${meta.id}
    """

    stub:
    """
    touch "${meta.id}.yaml"
    mkdir out_fasta
    touch "out_fasta/A.fasta"
    touch "out_fasta/B.fasta"
    """
}
