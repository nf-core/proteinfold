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
    val download_dir

    output:
    path download_dir, emit: db_path

    script:
    def args = task.ext.args ?: ''
    """
    set -e

    BASENAME=\$(basename "${source_url}")
    mkdir --parents $download_dir

    aria2c \\
        $args \\
        $source_url \\
        --dir=$download_dir \\

    if [[ \$BASENAME == *.tar.gz ]];
    then
        tar --extract --verbose --file="${download_dir}/\${BASENAME}" \
        --directory="${download_dir}" --preserve-permissions
        rm "${download_dir}/\${BASENAME}"
    fi

    if [[ \$BASENAME == *.gz && \$BASENAME == !(*.tar.gz) ]];
    then
	gunzip "${download_dir}/\${BASENAME}"
    fi
    """

    stub:
    """
    touch $download_dir
    """
}
