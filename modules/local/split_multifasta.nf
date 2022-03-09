process SPLIT_MULTI_FASTA {
	tag "${seq_name}"

	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

	input: 
	tuple val(seq_name), path(fasta_file)

	output:
	path ("*.fasta")

	"""
	awk -F ' ' '/^>/ {close(F); ID=\$1; gsub("^>", "", ID); F=ID".fasta"} {print >> F}' ${fasta_file}
	"""
}