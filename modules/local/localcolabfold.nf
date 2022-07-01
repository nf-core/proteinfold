process RUN_COLABFOLD {
    tag "${seq_name}"
    label 'customConf'
        container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/colabfold_proteinfold:v0.9' :
        'athbaltzis/colabfold_proteinfold:v0.9' }"

    input:
    tuple val(seq_name), path(fasta)
    val model_type
    path db
    val numRec

    output:
    path ("*relaxed_rank_*.pdb")

    script:
    if (model_type == 'AlphaFold2-ptm') {
    def args = task.ext.args ?: ''
    // def prefix = fasta.baseName //TODO ?  --templates \
    """
    colabfold_batch \
        $args \
        --num-recycle ${numRec} \
        --data ${db}/params/${model_type} \
        --model-type ${model_type} \
        ${fasta} \
        \$PWD
    """
    }
    else {
        def args = task.ext.args ?: ''
    // def prefix = fasta.baseName //TODO ?
    """
    echo "id,sequence" >> input.csv
    echo -e ${seq_name.sequence},`awk -F ' ' '!/^>/ {print \$0}' ${fasta} | tr "\n" ":" | awk '{gsub(/:\$/,""); print}'` >> input.csv
    colabfold_batch \
        $args \
        --num-recycle ${numRec} \
        --data ${db}/params/${model_type} \
        --model-type ${model_type} \
        input.csv \
        \$PWD
    for i in `find *_relaxed_rank_1*.pdb`; do cp \$i `echo \$i | sed "s|_relaxed_rank_|\t|g" | cut -f1`"_colabfold.pdb"; done
    """
    }

    stub:
    """
    touch ./"${fasta.baseName}"_colabfold.pdb
    """
}
