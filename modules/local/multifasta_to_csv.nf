process MULTIFASTA_TO_CSV {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("input.csv"), emit: input_csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    echo -e id,sequence'\\n'${meta.id},`awk '!/^>/ {print \$0}' ${fasta} | tr '\\n' ':' | sed 's/:\$//'` > input.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    touch input.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
    END_VERSIONS
    """
}
