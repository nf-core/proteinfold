process MMSEQS_TSV2EXPROFILEDB {
    tag "$db"
    label 'process_high'

    conda (params.enable_conda ? "bioconda::mmseqs2=14.7e284" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mmseqs2:14.7e284--pl5321hf1761c0_0':
        'quay.io/biocontainers/mmseqs2:14.7e284--pl5321hf1761c0_0' }"

    input:
    path db

    output:
    path (db)          , emit: db_exprofile
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    cd ${db}

    mmseqs tsv2exprofiledb \\
        "${db}" \\
        "${db}_db"
        $args

    cd ..

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mmseqs: \$(mmseqs | grep 'Version' | sed 's/MMseqs2 Version: //')
    END_VERSIONS
    """

    stub:
    """
    touch ${db}/${db}_db

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
