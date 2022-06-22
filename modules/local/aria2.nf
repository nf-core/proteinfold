process ARIA2 {
    label 'process_long'

    //container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/aria2:1.34.0--h2021cec_3' :
    //    'quay.io/biocontainers/aria2:1.34.0--h2021cec_3' }"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/mulled-v2-1fa26d1ce03c295fe2fdcf85831a92fbcbd7e8c2:59cdd445419f14abac76b31dd0d71217994cbcc9-0' :
    //     'quay.io/biocontainers/mulled-v2-1fa26d1ce03c295fe2fdcf85831a92fbcbd7e8c2:59cdd445419f14abac76b31dd0d71217994cbcc9-0' }"

    input:
    val source_url

    output:
    path ("*.*"), emit: ch_db

    script:
    def args = task.ext.args ?: ''
    file_name = source_url.split('/')[-1]
    """
    set -e

    aria2c \\
        $args \\
        $source_url
    """

    stub:
    """
    BASENAME=\$(basename "${source_url}")
    touch \$BASENAME
    """
}
