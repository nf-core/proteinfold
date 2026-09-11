process MULTIFASTA_TO_CSV {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("input.csv"), emit: input_csv
    tuple val("${task.process}"), val('sed'), eval('sed --version 2>&1 | sed "s/^.*GNU sed() //; s/ .*$//"'), emit: versions_sed, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    awk '/^>/ {printf("\\n%s\\n",\$0);next; } { printf("%s",\$0);}  END {printf("\\n");}' ${fasta} > single_line.fasta
    echo -e id,sequence'\\n'${meta.id},`awk '!/^>/ {print \$0}' single_line.fasta | tr '\\n' ':' | sed 's/:\$//' | sed 's/^://'` > input.csv
    """

    stub:
    """
    touch input.csv
    """
}
