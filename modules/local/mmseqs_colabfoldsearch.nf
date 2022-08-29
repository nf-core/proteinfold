process MMSEQS_COLABFOLDSEARCH {
    tag "$seq_name"
    label 'high'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/colabfold_proteinfold:v0.9' :
        'athbaltzis/colabfold_proteinfold:v0.9' }"

    input:
    tuple val(seq_name), path(fasta)
    path ('db/params')
    path uniref30
    path colabfold_db
    val db_load_mode

    output:
    tuple val(seq_name), path("${seq_name.sequence}.a3m"), emit: a3m

    script:
    def args = task.ext.args ?: ''
    // mmseqs touchdb ${db}/uniref30_2103_db --threads $task.cpus
    // mmseqs touchdb ${db}/colabfold_envdb_202108_db --threads $task.cpus
    """
    cp $uniref30/* ./db
    cp $colabfold_db/* ./db
    /colabfold_batch/colabfold-conda/bin/colabfold_search --db-load-mode ${db_load_mode} --threads $task.cpus ${fasta} ./db "result/"
    cp result/0.a3m ${seq_name.sequence}.a3m
    """

    stub:
    """
    touch result/${seq_name.sequence}.a3m
    """
}
