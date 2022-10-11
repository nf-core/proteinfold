process COMBINE_UNIPROT {

    conda (params.enable_conda ? "conda-forge::sed=4.7" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    path uniprot_sprot
    path uniprot_trembl

    output:
    path ('uniprot.fasta'), emit: ch_db
    path "versions.yml" , emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    set -e

    cat ${uniprot_sprot} >> ${uniprot_trembl}
    mv ${uniprot_trembl} uniprot.fasta
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    touch uniprot.fasta
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
    END_VERSIONS
    """
}
