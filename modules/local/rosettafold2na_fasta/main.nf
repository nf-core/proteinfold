process ROSETTAFOLD2NA_FASTA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("rf2na_input", type: "dir"), emit: rf2na_input
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //g'"), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    fasta_to_rosettafold.py "${meta.id}" "${fasta}"
    """

    stub:
    """
    mkdir -p rf2na_input
    touch rf2na_input/chain_map.tsv
    """
}
