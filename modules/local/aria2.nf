process ARIA2 {
    tag "$file_name"
    label 'process_long'
    label 'error_retry'


    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'docker://athbaltzis/debian:11.3' :
    //     'athbaltzis/debian:11.3' }" //TODO get rid of this container if the one below works
    conda (params.enable_conda ? "conda-forge::aria2=1.36.0 conda-forge::pigz=2.6 conda-forge::tar=1.34" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-69301472645cb9673ee25896a90852844f609980:67059f7bbd77178ef34cc40895191f5687211776-0' :
        'quay.io/biocontainers/mulled-v2-69301472645cb9673ee25896a90852844f609980:67059f7bbd77178ef34cc40895191f5687211776-0' }"

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
        --check-certificate=false \\
        $args \\
        $source_url
    """

    stub:
    """
    BASENAME=\$(basename "${source_url}")
    touch \$BASENAME
    """
}
