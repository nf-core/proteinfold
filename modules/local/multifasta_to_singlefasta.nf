process MULTIFASTA_TO_SINGLEFASTA {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.fasta"), emit: input_fasta
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    awk '/^>/ {printf("\\n%s\\n",\$0);next; } { printf("%s",\$0);}  END {printf("\\n");}' ${fasta} > single_line.fasta
    echo -e '>'${meta.id}'\\n'`awk '!/^>/ {print \$0}' single_line.fasta | tr '\\n' ':' | sed 's/:\$//' | sed 's/^://'` > ${meta.id}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
    END_VERSIONS
    """
}
