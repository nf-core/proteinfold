process RUN_MMSEQS2 {
    tag "${seq_name}"
    label 'high'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/colabfold_proteinfold:v0.9' :
        'athbaltzis/colabfold_proteinfold:v0.9' }"

    input:
    tuple val(seq_name), path(fasta)
    path db
    val threads
    val db_load_mode

    output:
    tuple val(seq_name), path("${seq_name.sequence}.a3m")

    script:
    def args = task.ext.args ?: ''
    """
    mmseqs touchdb ${db}/uniref30_2103_db --threads ${threads}
    mmseqs touchdb ${db}/colabfold_envdb_202108_db --threads ${threads}
    /colabfold_batch/colabfold-conda/bin/colabfold_search --db-load-mode ${db_load_mode} --threads ${threads} ${fasta} ${db} "result/"
    cp result/0.a3m ${seq_name.sequence}.a3m
    """

    stub:
    """
    touch ./result
    """
}
