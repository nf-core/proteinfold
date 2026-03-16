/*
 * Extract metrics from Boltz outputs
 */
process EXTRACT_METRICS_BOLTZ {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(raw)

    output:
    tuple val(meta), path("${meta.id}_plddt.tsv")          , emit: multiqc
    tuple val(meta), path("${meta.id}_boltz_msa.tsv")      , optional: true, emit: boltz_msa
    tuple val(meta), path("${meta.id}_*_pae.tsv")          , optional: true, emit: paes
    tuple val(meta), path("${meta.id}_0_pae.tsv")          , optional: true, emit: pae
    tuple val(meta), path("${meta.id}_ptm.tsv")            , optional: true, emit: ptms
    tuple val(meta), path("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    tuple val(meta), path("${meta.id}_chainwise_ptm.tsv")  , optional: true, emit: chainwise_ptm
    tuple val(meta), path("${meta.id}_chainwise_iptm.tsv") , optional: true, emit: chainwise_iptm
    path "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mapfile -t boltz_structs < <(find -L . -path "*boltz_results_*/predictions/${meta.id}/*.pdb" | sort)
    mapfile -t boltz_jsons < <(find -L . -path "*boltz_results_*/predictions/${meta.id}/confidence_*_model_*.json" | sort)
    mapfile -t boltz_npzs < <(find -L . -path "*boltz_results_*/predictions/${meta.id}/pae_*_model_*.npz" | sort)
    mapfile -t boltz_csvs < <(find -L . -path "*boltz_results_*/msa/${meta.id}_*.csv" | sort)

    if [[ "${'$'}{#boltz_structs[@]}" -eq 0 ]]; then
        echo "Could not find Boltz predicted structures for ${meta.id}" >&2
        exit 1
    fi

    cmd=(python3 "\$(command -v extract_metrics.py)" --name ${meta.id} --structs "${'$'}{boltz_structs[@]}")
    if [[ "${'$'}{#boltz_jsons[@]}" -gt 0 ]]; then
        cmd+=(--jsons "${'$'}{boltz_jsons[@]}")
    fi
    if [[ "${'$'}{#boltz_npzs[@]}" -gt 0 ]]; then
        cmd+=(--npzs "${'$'}{boltz_npzs[@]}")
    fi
    if [[ "${'$'}{#boltz_csvs[@]}" -gt 0 ]]; then
        cmd+=(--csvs "${'$'}{boltz_csvs[@]}")
    fi
    "${'$'}{cmd[@]}"

    if [[ -f "${meta.id}_msa.tsv" ]]; then
        mv "${meta.id}_msa.tsv" "${meta.id}_boltz_msa.tsv"
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_boltz_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_chainwise_ptm.tsv"
    touch "${meta.id}_chainwise_iptm.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
