process MMSEQS_CREATEINDEX {
    tag "$db"
    label 'process_long'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/mmseqs_proteinfold:v0.1' :
        'athbaltzis/mmseqs_proteinfold:v0.1' }"

    input:
    path db

    output:
    path("*.idx") , emit: idx

    script:
    def args = task.ext.args ?: ''
    // mmseqs createindex "uniref30_2103_db" tmp1 --remove-tmp-files 1
    """
    mmseqs createindex \\
        $db \\
        tmp1 \\
        --remove-tmp-files 1 \\
        $args
    """

    stub:
    """
    touch ${db}.idx
    """
}
