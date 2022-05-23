process DOWNLOAD_AF2_DB {
    label 'long'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("db") , emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_all_data.sh \$PWD/db $args
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_COLABFOLD_PARAMS {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("params") , emit: db_path

    script:
    """
    download_colabfold_params.sh params
    """

    stub:
    """
    touch params
    """
}
