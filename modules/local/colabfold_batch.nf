process COLABFOLD_BATCH {
    tag "$seq_name"
    label 'customConf'
        container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/colabfold_proteinfold:v0.9' :
        'athbaltzis/colabfold_proteinfold:v0.9' }"

    input:
    tuple val(seq_name), path(fasta)
    val   model_type
    path ('params/*')
    path ('colabfold_db/*')
    path ('uniref30/*')
    val   numRec

    output:
    path ("*${fasta.baseName}*"), emit: pdb

    script:
    def args = task.ext.args ?: ''
    """
    cp params/alphafold_params_*/* params/
    colabfold_batch \\
        $args \\
        --num-recycle ${numRec} \\
        --data \$PWD \\
        --model-type ${model_type} \\
        ${fasta} \\
        \$PWD
    for i in `find *_relaxed_rank_1*.pdb`; do cp \$i `echo \$i | sed "s|_relaxed_rank_|\t|g" | cut -f1`"_colabfold.pdb"; done
        """

    stub:
    """
    touch ./"${fasta.baseName}"_colabfold.pdb
    """
}
