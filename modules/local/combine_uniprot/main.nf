process COMBINE_UNIPROT {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    path uniprot_sprot
    path uniprot_trembl

    output:
    path ('uniprot.fasta'), emit: ch_db
    tuple val("${task.process}"), val('sed'), eval('sed --version 2>&1 | sed "s/^.*GNU sed) //; s/ .*$//"'), emit: versions_sed, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
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
