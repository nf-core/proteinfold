process DOWNLOAD_AF2_PARAMS {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_alphafold_params.sh \$PWD
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_SMALL_BFD {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_small_bfd.sh \$PWD
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_BFD {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_bfd.sh \$PWD
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_MGNIFY {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_mgnify.sh \$PWD
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_PDB70 {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_pdb70.sh \$PWD
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_PDB_MMCIF {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_pdb_mmcif.sh \$PWD
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_UNICLUST30 {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_uniclust30.sh \$PWD
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_UNIREF90 {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_uniref90.sh \$PWD
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_UNIPROT {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_uniprot.sh \$PWD
    """

    stub:
    """
    touch db
    """
}

process DOWNLOAD_PDB_SEQRES {
    label 'long'
    label 'download'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    path("*")
    tuple val(db), path("*"), emit: db_path


    script:
    def args = task.ext.args ?: ''
    """
    download_pdb_seqres.sh \$PWD
    """

    stub:
    """
    touch db
    """
}