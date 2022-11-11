process COLABFOLD_BATCH {
    tag "$seq_name"
    label 'process_medium'

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
    path ("*")         , emit: pdb
    path ("*_mqc.png") , emit: multiqc
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def VERSION = '1.2.0' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    ln -r -s params/alphafold_params_*/* params/
    colabfold_batch \\
        $args \\
        --num-recycle ${numRec} \\
        --data \$PWD \\
        --model-type ${model_type} \\
        ${fasta} \\
        \$PWD
    for i in `find *_relaxed_rank_1*.pdb`; do cp \$i `echo \$i | sed "s|_relaxed_rank_|\t|g" | cut -f1`"_colabfold.pdb"; done
    for i in `find *.png -maxdepth 0`; do cp \$i \${i%'.png'}_mqc.png; done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold_batch: $VERSION
    END_VERSIONS
    """

    stub:
    def VERSION = '1.2.0' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch ./"${fasta.baseName}"_colabfold.pdb
    touch ./"${fasta.baseName}"_mqc.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold_batch: $VERSION
    END_VERSIONS
    """
}
