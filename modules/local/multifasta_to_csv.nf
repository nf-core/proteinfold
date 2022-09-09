process MULTIFASTA_TO_CSV {
    tag "$seq_name"
        container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/colabfold_proteinfold:v0.9' :
        'athbaltzis/colabfold_proteinfold:v0.9' }"

    input:
    tuple val(seq_name), path(fasta)

    output:
    tuple val(seq_name), path("input.csv"), emit: input_csv

    script:
    """
    echo "id,sequence" >> input.csv
    echo -e ${seq_name.sequence},`awk -F ' ' '!/^>/ {print \$0}' ${fasta} | tr "\n" ":" | awk '{gsub(/:\$/,""); print}'` >> input.csv
    """

    stub:
    """
    touch input.csv
    """
}
