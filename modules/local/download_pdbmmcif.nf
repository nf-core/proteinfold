/*
 * Download PDB MMCIF database
 */
process DOWNLOAD_PDBMMCIF {
    label 'process_low'
    label 'error_retry'

    conda (params.enable_conda ? "bioconda::aria2=1.36.0 conda-forge::rsync=3.2.7" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-4a7c46784ad871c48746744c6b8dbc5d0a97b9ca:33e61a87922824f8afcecf88a7717a2d4cb514e9-0' :
        'quay.io/biocontainers/mulled-v2-4a7c46784ad871c48746744c6b8dbc5d0a97b9ca:33e61a87922824f8afcecf88a7717a2d4cb514e9-0' }"

    input:
    val source_url_pdb_mmcif
    val source_url_pdb_obsolete

    output:
    path ('*')         , emit: ch_db
    path "versions.yml", emit: versions

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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | head -1 | sed 's/^.*GNU sed) //; s/ .*\$//')
        rsync: \$(rsync --version | head -1 | sed 's/^rsync  version //; s/  protocol version [[:digit:]]*//')
        aria2c: \$( aria2c -v | head -1 | sed 's/aria2 version //' )
    END_VERSIONS
    """

    stub:
    """
    touch obsolete.dat
    mkdir mmcif_files

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
