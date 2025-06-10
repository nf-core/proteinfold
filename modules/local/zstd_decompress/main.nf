process ZSTD_DECOMPRESS {
    tag "$archive"
    label 'process_single'

    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0a/0a27033ae5d8add5059f44c62a6004bfcd061d33020edee095fbb204e6f32fee/data' :
        'community.wave.seqera.io/library/zstd:b5faa75d5b75be7f' }"

    input:
    tuple val(meta), path(archive)

    output:
    tuple val(meta), path("$prefix"), emit: decompressed
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: ( meta.id ? "${meta.id}" : archive.baseName.toString().replaceFirst(/\.zst$/, ""))
    """
    zstd \\
        --decompress \\
        $args \\
        $archive

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        zstd: \$(echo \$(zstd --version 2>&1) | grep -o 'v[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+')
    END_VERSIONS
    """

    stub:
    prefix   = task.ext.prefix ?: ( meta.id ? "${meta.id}" : archive.baseName.toString().replaceFirst(/\.zst$/, ""))
    """
    touch ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        zstd: \$(echo \$(zstd --version 2>&1) | grep -o 'v[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+')
    END_VERSIONS
    """
}
