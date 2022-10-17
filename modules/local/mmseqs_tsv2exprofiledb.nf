process MMSEQS_TSV2EXPROFILEDB {
    tag "$db"
    label 'process_high'
    label 'long'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/mmseqs_proteinfold:v0.1' :
        'athbaltzis/mmseqs_proteinfold:v0.1' }"

    input:
    path db

    output:
    path (db)          , emit: db_exprofile
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    cd ${db}
    mmseqs tsv2exprofiledb \\
        "${db}" \\
        "${db}_db"
    cd ..
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mmseqs: \$(mmseqs | grep 'Version' | sed 's/MMseqs2 Version: //')
    END_VERSIONS
    """

    stub:
    """
    touch ${db}_exprofile

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
