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
        for dictionary in \
            "ModelArchive:${projectDir}/bin/dicts/mmcif_ma.sdb" \
            "PDBx:${projectDir}/bin/dicts/mmcif_pdbx_v50.sdb"; do
            validation_name="\${dictionary%%:*}"
            dictionary_path="\${dictionary#*:}"
            rm -f "\${mmcif_file}-diag.log" "\${mmcif_file}-parser.log"
            CifCheck -f "\${mmcif_file}" -dictSdb "\${dictionary_path}"
            if [ -s "\${mmcif_file}-diag.log" ] || [ -s "\${mmcif_file}-parser.log" ]; then
                echo "\${validation_name} CifCheck validation errors in \${mmcif_file}:" >&2
                [ -s "\${mmcif_file}-diag.log" ]   && cat "\${mmcif_file}-diag.log"   >&2
                [ -s "\${mmcif_file}-parser.log" ] && cat "\${mmcif_file}-parser.log" >&2
                exit 1
            fi
        done
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CifCheck: "2.500"
    END_VERSIONS
    """
}
