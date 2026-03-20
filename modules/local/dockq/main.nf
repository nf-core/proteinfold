process DOCKQ {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/dockq:2.1.3--pyhdfd78af_0' :
        'community.wave.seqera.io/library/dockq:2.1.3--12e64dc3fc7d0a10' }"

    input:
    tuple val(meta), path(inputpdb), path(reference)

    output:
    tuple val(meta), path("*.txt"), emit: txt
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    DockQ \\
        ${inputpdb} ${reference} \\
        $args \\
        > DockQ_${inputpdb.baseName}_vs_${reference.baseName}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dockq: \$(DockQ --version 2>&1 | sed 's/DockQ v//g')
    END_VERSIONS
    """

    stub:
    """
    touch DockQ_${inputpdb.baseName}_vs_${reference.baseName}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dockq: \$(DockQ --version 2>&1 | sed 's/DockQ v//g')
    END_VERSIONS
    """
}
