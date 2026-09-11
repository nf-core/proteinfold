/*
 * Download PDB MMCIF database
 */
process DOWNLOAD_PDBMMCIF_AF3 {
    tag "${source_url_pdb_mmcif}"
    label 'process_low'
    label 'error_retry'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fa/fa33501a8b3ff76af2b4a13c68af6255d120b1e9ff1b4c94bfb4e6de627bfd71/data' :
        'community.wave.seqera.io/library/wget_zstd:588693a86d59d291' }"

    input:
    val source_url_pdb_mmcif

    output:
    path ('mmcif_files/*.cif'), emit: ch_db
    tuple val("${task.process}"), val('wget'), eval('wget --version 2>&1 | grep "GNU Wget" | cut -f3 -d " "'), emit: versions_wget, topic: versions
    tuple val("${task.process}"), val('untar'), eval('tar --version 2>&1 | sed "s/^.*(GNU tar) //; s/ Copyright.*//"'), emit: versions_untar, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mkdir mmcif_files

    wget --quiet --output-document=- ${source_url_pdb_mmcif} | \\
        tar --use-compress-program=zstd \\
        --strip-components 1 \\
        -xf - \\
        --directory="./mmcif_files"
    """

    stub:
    """
    mkdir mmcif_files
    touch mmcif_files/stub.cif
    """
}
