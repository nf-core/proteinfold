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
    def dictionary_name = meta.validation_dictionary ?: 'ModelArchive'
    def dictionary_files = [
        'ModelArchive': 'mmcif_ma.sdb',
        'PDBx': 'mmcif_pdbx_v50.sdb'
    ]
    if (!dictionary_files.containsKey(dictionary_name)) {
        error "Unsupported CIFCHECK validation dictionary: ${dictionary_name}"
    }
    def dictionary_path = "${projectDir}/bin/dicts/${dictionary_files[dictionary_name]}"
    """
    for mmcif_file in ${mmcif}; do
        CifCheck -f "\${mmcif_file}" -dictSdb ${dictionary_path}
        if [ -s "\${mmcif_file}-diag.log" ] || [ -s "\${mmcif_file}-parser.log" ]; then
            echo "${dictionary_name} CifCheck validation errors in \${mmcif_file}:" >&2
            [ -s "\${mmcif_file}-diag.log" ]   && cat "\${mmcif_file}-diag.log"   >&2
            [ -s "\${mmcif_file}-parser.log" ] && cat "\${mmcif_file}-parser.log" >&2
            exit 1
        fi
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CifCheck: "2.500"
    END_VERSIONS
    """
}
