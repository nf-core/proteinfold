process RUN_COLABFOLD {
	tag "${seq_name}"
	label 'customConf'
//TODO
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/colabfold_proteinfold:v0.2' :
		'docker://athbaltzis/colabfold_proteinfold:v0.2' }"

	input:
	tuple val(seq_name), path(fasta)
	val model_type
	val	cpu_flag

	output:
	path ("*")
	path ("*_alphafold.pdb")

	script:
    def args = task.ext.args ?: ''
    // def prefix = fasta.baseName //TODO ?
    """
	colabfold_batch \
        --amber \
        --templates \
		$args \
        --num-recycle 3 \
        --model-type ${model_type} \
        ${fasta} \
        \$PWD
        

	for i in `find *_relaxed_rank_1*.pdb`; do cp \$i `echo \$i | sed "s|_relaxed_rank_|\t|g" | cut -f1`"_alphafold.pdb"; done
	"""

    stub:
    """
    touch *_alphafold.pdb
    """
}
