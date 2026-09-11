process BOLTZ_FASTA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.14' :
        'biocontainers/python:3.14' }"

    input:
    tuple val(meta), path(fasta)

    output:
<<<<<<< HEAD
    tuple val(meta), path ("output_fasta/*.fasta"), emit: formatted_fasta
=======
    tuple val(meta), path ("output_fasta/*.fasta"), path(msa), emit: formatted_fasta
>>>>>>> 776722aa (Remove modelCIF work, only topic channels migration)
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //g'"), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
<<<<<<< HEAD
    fasta_to_boltz.py ${fasta} ${meta.id}
=======
    fasta_to_boltz.py ${fasta} ${meta.id} ${msa_files}
>>>>>>> 776722aa (Remove modelCIF work, only topic channels migration)
    """

    stub:
    """
    mkdir output_fasta
    touch "output_fasta/${meta.id}.fasta"
    """
}
