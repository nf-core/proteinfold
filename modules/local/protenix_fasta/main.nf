process PROTENIX_FASTA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(fasta), path(msa)

    output:
    tuple val(meta), path ("${meta.id}.json"), path("msa_protenix"), emit: protenix_json
    path "versions.yml"                                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def msa_files = msa ? "--msa " + msa.join(' ') : ''
    """
    mkdir -p msa_protenix
    fasta_to_protenix_json.py ${fasta} ${meta.id} -o . ${msa_files}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p msa_protenix
    echo '[]' > "${meta.id}.json"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
