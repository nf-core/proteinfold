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

    output:
    path ('uniprot.fasta'), emit: ch_db

    script:
    def args = task.ext.args ?: ''
    """
    set -e

    cat ${uniprot_sprot} >> ${uniprot_trembl}
    mv ${uniprot_trembl} uniprot.fasta
    """

    stub:
    """
    touch uniprot.fasta
    """
}
