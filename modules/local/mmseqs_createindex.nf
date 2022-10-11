process MMSEQS_CREATEINDEX {
    tag "$db"
    label 'proces_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/mmseqs_proteinfold:v0.1' :
        'athbaltzis/mmseqs_proteinfold:v0.1' }"

    input:
    path db

    output:
    path(db) , emit: db_index
    path "versions.yml" , emit: versions


    script:
    def args = task.ext.args ?: ''
    // mmseqs createindex "uniref30_2103_db" tmp1 --remove-tmp-files 1
    """
    cd $db
    mmseqs createindex \\
        ${db}_exprofile \\
        tmp1 \\
        --remove-tmp-files 1 \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mmseqs: \$(mmseqs | grep 'Version' | sed 's/MMseqs2 Version: //')
    END_VERSIONS
    """

    stub:
    """
    touch ${db}/${db}.idx

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
