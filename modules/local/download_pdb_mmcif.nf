/*
 * Download PDB MMCIF database
 */
process DOWNLOAD_PDB_MMCIF {
    label 'long'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val source_url_pdb_mmcif
    val source_url_pdb_obsolete
    val download_dir

    output:
    path download_dir, emit: db_path

    script:
    def args = task.ext.args ?: ''
    """
    set -e

    RAW_DIR="${download_dir}/raw"
    MMCIF_DIR="${download_dir}/mmcif_files"
    BASENAME=\$(basename "${source_url}")

    mkdir --parents "\${RAW_DIR}"
    rsync \\
        --recursive \\
        --links \\
        --perms \\
        --times \\
        --compress \\
        --info=progress2 \\
        --delete \\
        --port=33444 \\
        $source_url_pdb_mmcifs \\
        "\${RAW_DIR}"

    echo "Unzipping all mmCIF files..."
    find "\${RAW_DIR}/" -type f -iname "*.gz" -exec gunzip {} +

    echo "Flattening all mmCIF files..."
    mkdir --parents "\${MMCIF_DIR}"
    find "\${RAW_DIR}" -type d -empty -delete  # Delete empty directories.
    for subdir in "\${RAW_DIR}"/*; do
        mv "\${subdir}/"*.cif "\${MMCIF_DIR}"
    done

    # Delete empty download directory structure.
    find "\${RAW_DIR}" -type d -empty -delete

    aria2c \\
        $source_url_pdb_obsolete \\
        --dir=${download_dir}
    """

    stub:
    """
    touch $download_dir
    """
}
