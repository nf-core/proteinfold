process MMSEQS_COLABFOLDSEARCH {
    tag "$meta.id"
    label 'process_high_memory'
    label 'process_high'

    container "ghcr.io/tlitfin/wisps-colabfold-search:1.1"

    input:
    tuple val(meta), path(fasta)
    path ('db/*')
    path ('uniref30/*')

    output:
    tuple val(meta), path("**.a3m"), emit: a3m
    tuple val(meta), path("**.json"), emit: json
    tuple val("${task.process}"), val('colabfold_search'), eval("pip list | grep \"^colabfold\" | awk '{print \\\$2}' 2>/dev/null || echo \"unknown\""), emit: versions_colabfold_search, topic: versions
    tuple val("${task.process}"), val('mmseqs'), eval("mmseqs version 2>/dev/null | head -1"), emit: versions_mmseqs, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local MMSEQS_COLABFOLDSEARCH module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''

    """
    for f in uniref30/*; do
        if [ ! -e "db/\$(basename \$f)" ]; then
            ln -sf \$(realpath \$f) db/\$(basename \$f)
        else
            echo "WARNING: skipping uniref30/\$(basename \$f) -- already present from colabfold_db" >&2
        fi
    done

    # Link the taxonomy/pairing sidecars that mmseqs pairaln resolves next to the target DB; absence is fine for single-chain flows.
    for f in uniref30/*_mapping uniref30/*_taxonomy uniref30/*_nodes.dmp uniref30/*_names.dmp uniref30/*_merged.dmp uniref30/*_lookup uniref30/*.idx_mapping uniref30/*.idx_taxonomy; do
        if [ -e "\$f" ] && [ ! -e "db/\$(basename "\$f")" ]; then
            ln -sf "\$(realpath "\$f")" "db/\$(basename "\$f")"
        fi
    done

    colabfold_search \\
        $args \\
        --threads $task.cpus "${fasta}" \\
        ./db \\
        --af3-json \\
        "results/"

    # Fail loudly rather than silently dropping the sample from the downstream joins.
    if [[ -z "\$(find results -type f -name '*.a3m' -print -quit)" ]]; then
        echo "MMSEQS_COLABFOLDSEARCH produced no a3m files for ${meta.id}" >&2
        exit 1
    fi
    if [[ -z "\$(find results -type f -name '*.json' -print -quit)" ]]; then
        echo "MMSEQS_COLABFOLDSEARCH produced no AlphaFold3 JSON for ${meta.id}" >&2
        exit 1
    fi

    # 'pip list | grep' exits 0 even without a match, so default an empty probe to 'unknown'.
    colabfold_search_version="\$(pip list 2>/dev/null | grep "^colabfold " | awk '{print \$2}' || true)"
    if [[ -z "\$colabfold_search_version" ]]; then
        colabfold_search_version=unknown
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold_search: \$colabfold_search_version
        mmseqs: \$(mmseqs version)
    END_VERSIONS
    """

    stub:
    """
    mkdir results
    touch results/${meta.id}.a3m
    touch results/${meta.id}.json
    """
}
