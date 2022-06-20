process COMBINE_UNIPROT {

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/aria2:1.34.0--h2021cec_3' :
        'quay.io/biocontainers/aria2:1.34.0--h2021cec_3' }"

    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/mulled-v2-1fa26d1ce03c295fe2fdcf85831a92fbcbd7e8c2:59cdd445419f14abac76b31dd0d71217994cbcc9-0' :
    //     'quay.io/biocontainers/mulled-v2-1fa26d1ce03c295fe2fdcf85831a92fbcbd7e8c2:59cdd445419f14abac76b31dd0d71217994cbcc9-0' }"

    input:
    path uniprot_sprot
    path uniprot_trembl
    val  output_dir

    output:
    path output_dir, emit: db_path

    script:
    def args = task.ext.args ?: ''
    """
    set -e
    mkdir --parents $output_dir 

    cat ${uniprot_sprot}/uniprot_sprot.fasta >> ${uniprot_trembl}/uniprot_trembl.fasta
    cp ${uniprot_trembl}/uniprot_trembl.fasta ${output_dir}/uniprot.fasta
    """

    stub:
    """
    touch $output_dir
    """
}
