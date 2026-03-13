/*
 * Extract metrics from structure prediction serialized outputs
 */
process EXTRACT_METRICS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(raw), val(mode), path(features)

    output:
    tuple val(meta), path("${meta.id}_plddt.tsv")          , emit: multiqc
    tuple val(meta), path("${meta.id}_alphafold2_msa.tsv") , emit: msa
    tuple val(meta), path("${meta.id}_*_pae.tsv")          , optional: true, emit: paes
    tuple val(meta), path("${meta.id}_0_pae.tsv")          , optional: true, emit: pae
    tuple val(meta), path("${meta.id}_ptm.tsv")            , optional: true, emit: ptms
    tuple val(meta), path("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    path "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    if [[ "${mode}" != "alphafold2" ]]; then
        echo "Unsupported mode for EXTRACT_METRICS: ${mode}" >&2
        exit 1
    fi

    # Handle both regular files and symlink-staged files from Nextflow work dirs.
    mapfile -t ranked_structs < <(find -L . -name "ranked*.pdb" | sort)
    if [[ "${'$'}{#ranked_structs[@]}" -eq 0 ]]; then
        echo "Could not find ranked AlphaFold2 structures in raw output" >&2
        exit 1
    fi

    features_pkl=\$(find -L . -name "features.pkl" | head -n 1)
    if [[ -z "\$features_pkl" && "${features}" != "NO_FILE" ]]; then
        features_pkl="${features}"
    fi
    if [[ -z "\$features_pkl" ]]; then
        echo "Could not find features.pkl in raw output" >&2
        exit 1
    fi

    mapfile -t pkl_files < <(find -L . -name "*.pkl" | sort)

    extract_metrics.py --name ${meta.id} \
        --pkls "\$features_pkl" "${'$'}{pkl_files[@]}" \
        --structs "${'$'}{ranked_structs[@]}"

    mv "${meta.id}_msa.tsv" "${meta.id}_alphafold2_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_alphafold2_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
