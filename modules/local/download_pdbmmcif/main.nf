/*
 * Download PDB MMCIF database
 */
process DOWNLOAD_PDBMMCIF {
    tag "${source_url_pdb_mmcif}"
    label 'process_low'
    label 'error_retry'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/3c/3c2e1079a0721851248bd2aa45f3d4cd32bfdb7395d609132567d772150965cc/data' :
        'community.wave.seqera.io/library/aria2_rsync:1627a7e9b559cfa0' }"

    input:
    val source_url_pdb_mmcif

    output:
    path ('*')         , emit: ch_db
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

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
    find ./raw -type f -name '*.[gG][zZ]' -exec gunzip {} \\;

    echo "Flattening all mmCIF files..."
    mkdir mmcif_files
    find ./raw -type d -empty -delete  # Delete empty directories.
    for subdir in ./raw/*; do
        mv "\${subdir}/"*.cif ./mmcif_files
    done

    # Delete empty download directory structure.
    find ./raw -type d -empty -delete

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(echo \$(sed --version 2>&1) | head -1 | sed 's/^.*GNU sed) //; s/ .*\$//')
        rsync: \$(rsync --version | head -1 | sed 's/^rsync  version //; s/  protocol version [[:digit:]]*//')
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
