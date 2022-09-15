/*
 * Download PDB MMCIF database
 */
process DOWNLOAD_PDBMMCIF {
    label 'process_medium'
    label 'error_retry'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/debian:11.3' :
        'athbaltzis/debian:11.3' }"

    input:
    val source_url_pdb_mmcif
    val source_url_pdb_obsolete

    output:
    path ('*'), emit: ch_db

    script:
    def args = task.ext.args ?: ''
    """
    set -euo pipefail

    mkdir raw

    rsync \\
        --recursive \\
        --links \\
        --perms \\
        --times \\
        --compress \\
        --info=progress2 \\
        --delete \\
        --port=33444 \\
        $source_url_pdb_mmcif \\
        raw

    echo "Unzipping all mmCIF files..."
    find ./raw -type f -iname "*.gz" -exec gunzip {} +

    echo "Flattening all mmCIF files..."
    mkdir mmcif_files
    find ./raw -type d -empty -delete  # Delete empty directories.
    for subdir in ./raw/*; do
        mv "\${subdir}/"*.cif ./mmcif_files
    done

    # Delete empty download directory structure.
    find ./raw -type d -empty -delete

    aria2c \\
        $source_url_pdb_obsolete
    """

    stub:
    """
    touch obsolete.dat
    mkdir mmcif_files
    """
}
