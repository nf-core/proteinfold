process BOLTZ_YAML_TO_COLABFOLD_FASTA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "nf-core/proteinfold_boltz:2.0.0"

    input:
    tuple val(meta), path(boltz_yaml)

    output:
    tuple val(meta), path("${meta.id}.fasta"), emit: query_fasta
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    boltz_yaml_to_colabfold_fasta.py ${boltz_yaml} --id ${meta.id} --output ${meta.id}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}.fasta"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
