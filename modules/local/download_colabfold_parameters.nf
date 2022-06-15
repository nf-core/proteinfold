/*
 * Download Colabfold parameters
 */
process DOWNLOAD_COLABFOLD_PARAMS {
    label 'long'
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
