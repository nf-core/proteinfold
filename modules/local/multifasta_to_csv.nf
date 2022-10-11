process MULTIFASTA_TO_CSV {
    tag "$seq_name"
        container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/colabfold_proteinfold:v0.9' :
        'athbaltzis/colabfold_proteinfold:v0.9' }"

    input:
    tuple val(seq_name), path(fasta)

    output:
    tuple val(seq_name), path("input.csv"), emit: input_csv
    path "versions.yml" , emit: versions

    script:
    """
    echo "id,sequence" >> input.csv
    echo -e ${seq_name.sequence},`awk -F ' ' '!/^>/ {print \$0}' ${fasta} | tr "\n" ":" | awk '{gsub(/:\$/,""); print}'` >> input.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
        gawk: \$(awk -Wversion 2>/dev/null | sed 's/.*wk //; s/,.*$//')
    END_VERSIONS
    """

    stub:
    """
    touch input.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | sed 's/^.*GNU sed) //; s/ .*\$//')
        gawk: \$(awk -Wversion 2>/dev/null | sed 's/.*wk //; s/,.*$//')
    END_VERSIONS
    """
}
