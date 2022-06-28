process DOWNLOAD_COLABFOLD_PARAMS {
    label 'long'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val db

    output:
    tuple val(db), path("params") , emit: db_path

    script:
    """
    download_colabfold_params.sh params
    """

    stub:
    """
    touch params
    """
}

process DOWNLOAD_UNIREF30 {
    label 'long'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/mmseqs_proteinfold:v0.1' :
        'athbaltzis/mmseqs_proteinfold:v0.1' }"

    input:
    val db

    output:
    tuple val(db), path("*") , emit: db_path

    script:
    """
    wget -O "uniref30_2103.tar.gz" "http://wwwuser.gwdg.de/~compbiol/colabfold/uniref30_2103.tar.gz" && set -e && return 0
    tar xzvf "uniref30_2103.tar.gz"
    mmseqs tsv2exprofiledb "uniref30_2103" "uniref30_2103_db"
    mmseqs createindex "uniref30_2103_db" tmp1 --remove-tmp-files 1
    rm uniref30_2103.tar.gz
    """

    stub:
    """
    touch uniref30_2103_db
    """
}


process DOWNLOAD_COLABDB {
    label 'long'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/mmseqs_proteinfold:v0.1' :
        'athbaltzis/mmseqs_proteinfold:v0.1' }"

    input:
    val db

    output:
    tuple val(db), path("*") , emit: db_path

    script:
    """
    wget -O "colabfold_envdb_202108.tar.gz" "http://wwwuser.gwdg.de/~compbiol/colabfold/colabfold_envdb_202108.tar.gz" && set -e && return 0
    tar xzvf "colabfold_envdb_202108.tar.gz"
    mmseqs tsv2exprofiledb "colabfold_envdb_202108" "colabfold_envdb_202108_db"
    mmseqs createindex "colabfold_envdb_202108_db" tmp2 --remove-tmp-files 1
    rm colabfold_envdb_202108.tar.gz
    """

    stub:
    """
    touch colabfold_envdb_202108_db
    """
}
