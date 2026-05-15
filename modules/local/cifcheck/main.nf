process CIFCHECK {
    tag "$meta.id-$meta.model"
    label 'process_single'

    input:
    tuple val(meta), path(mmcif)

    output:
    tuple val(meta), path(mmcif), emit: modelcif
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    for mmcif_file in ${mmcif}; do
        CifCheck -f "\${mmcif_file}" -dictSdb ${projectDir}/bin/dicts/mmcif_pdbx_v50.sdb
        if [ -s "\${mmcif_file}-diag.log" ]; then
            echo "PDBx CifCheck validation errors in \${mmcif_file}:" >&2
            cat "\${mmcif_file}-diag.log" >&2
            exit 1
        fi
        CifCheck -f "\${mmcif_file}" -dictSdb ${projectDir}/bin/dicts/mmcif_ma.sdb
        if [ -s "\${mmcif_file}-diag.log" ]; then
            echo "MA CifCheck validation errors in \${mmcif_file}:" >&2
            cat "\${mmcif_file}-diag.log" >&2
            exit 1
        fi
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CifCheck: "2.500"
    END_VERSIONS
    """
}
