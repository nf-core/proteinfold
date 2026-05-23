process MERGE_BOLTZ_MSA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "nf-core/proteinfold_boltz:2.0.0"

    input:
    tuple val(meta), path(original_yaml, stageAs: 'original.yaml'), path(mmseqs_yaml, stageAs: 'mmseqs.yaml'), path(msa_csv, stageAs: 'msa_csv/*')

    output:
    tuple val(meta), path ("${meta.id}.yaml"), path ("merged_msa/*.csv"), emit: boltz_data
    path "versions.yml"                                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mkdir -p merged_msa
    merge_boltz_msa.py \\
        --original_yaml ${original_yaml} \\
        --mmseqs_yaml ${mmseqs_yaml} \\
        --msa_csv_dir msa_csv \\
        --output_yaml ${meta.id}.yaml \\
        --output_csv_dir merged_msa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p merged_msa
    touch "${meta.id}.yaml"
    touch "merged_msa/${meta.id}_0.csv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
