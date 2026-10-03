process COLABFOLD2_INFERENCE {
    tag "$meta.id ($model_type)"
    label 'process_medium'
    label 'process_gpu'

    container "ghcr.io/jscgh/proteinfold_colabfold:af3-preview-f850f0f"

    input:
    tuple val(meta), path(input)
    val model_type
    val use_esm
    val public_mode
    val num_recycles
    path params_path

    output:
    path "raw/**"                                             , optional: true, emit: raw
    tuple val(meta), path("${meta.id}_colabfold2.cif")        , optional: true, emit: top_ranked_structure
    tuple val(meta), path("raw/*_rank_*.cif")                 , optional: true, emit: structures
    tuple val(meta), path("${meta.id}_colabfold2_msa.tsv")    , optional: true, emit: msa
    tuple val(meta), path("${meta.id}_1_pae.tsv")             , optional: true, emit: pae
    tuple val(meta), path("${meta.id}_ptm.tsv")               , optional: true, emit: ptms
    tuple val(meta), path("${meta.id}_iptm.tsv")              , optional: true, emit: iptms
    tuple val(meta), path("${meta.id}_ipsae.tsv")             , optional: true, emit: ipsaes
    tuple val(meta), path("${meta.id}_chainwise_iptm.tsv")    , optional: true, emit: chainwise_iptms
    tuple val(meta), path("${meta.id}_chainwise_ipsae.tsv")   , optional: true, emit: chainwise_ipsaes
    tuple val(meta), path("${meta.id}_plddt.tsv")             , optional: true, emit: plddt
    tuple val(meta), path("${meta.id}_confidence.tsv")        , optional: true, emit: confidence
    tuple val(meta), path("raw/*_scores_rank_*.json")         , optional: true, emit: scores
    tuple val("${task.process}"), val('colabfold'), eval("python3 -c 'import importlib.metadata; print(importlib.metadata.version(\"colabfold\"))' 2>/dev/null || echo \"unknown\""), emit: versions_colabfold, topic: versions
    tuple val("${task.process}"), val('colabfold_commit'), val('f850f0f22f007355bd264d48e9ed263d59331426'), emit: versions_colabfold_commit, topic: versions
    tuple val("${task.process}"), val('alphafold3_colabfold'), eval("python3 -c 'import importlib.metadata; print(importlib.metadata.version(\"alphafold3-colabfold\"))' 2>/dev/null || echo \"unknown\""), emit: versions_alphafold3_colabfold, topic: versions
    tuple val("${task.process}"), val('jax'), eval("python3 -c 'import jax; print(jax.__version__)' 2>/dev/null || echo \"unknown\""), emit: versions_jax, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local COLABFOLD2_INFERENCE module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    def use_esm_arg = use_esm ? '--use-esm' : ''
    def precision = task.ext.weights_precision ?: 'fp32'
    def input_files = input instanceof Collection ? input.collect { file_path -> file_path.name } : [input.name]
    if (input_files.size() != 1) {
        error("COLABFOLD2_INFERENCE received multiple inputs for sample '${meta.id}'. Use --split_fasta to run each FASTA record independently.")
    }
    def require_msa_output = input_files.any { name -> name ==~ /(?i).*\.(fa|faa|fasta)$/ }
    // Stage the input behind a symlink so colabfold_batch receives one directory.
    def shell_quote = { name -> "'" + name.replace("'", "'\\''") + "'" }
    def quoted_input_files = input_files.collect(shell_quote).join(' ')

    """
    if ! command -v colabfold_batch >/dev/null 2>&1; then
        echo "COLABFOLD2_INFERENCE: colabfold_batch is missing or not executable on the container PATH" >&2
        exit 1
    fi
    if ! python3 -c 'import colabfold, jax'; then
        echo "COLABFOLD2_INFERENCE: runtime import validation failed (colabfold/jax not importable, see traceback above)" >&2
        exit 1
    fi
    mkdir -p msa_in
    for f in ${quoted_input_files}; do
        ln -s "\$PWD/\$f" msa_in/
        if [[ "\$f" == *.json ]]; then
            python3 -c 'import json, sys; d=json.load(open(sys.argv[1])); n=len(d) if isinstance(d, list) else 1; sys.exit(f"ColabFold2 requires one AlphaFold3 job per samplesheet row; {sys.argv[1]} contains {n} jobs") if n != 1 else None' "\$f"
        fi
    done

    # Register GPU kinds that JAX 0.11.1's Pallas device table misses (it matches by
    # name, e.g. 'NVIDIA L40S', V100) so kernels lower normally on those devices.
    cat > sitecustomize.py <<'EOF'
    def _register_missing_gpu_kinds():
        try:
            from jax._src.pallas.triton import gpu_info as gi
        except Exception:
            return
        def add(kind, arch, cc):
            if kind not in gi.registry:
                gi.registry[kind] = lambda: gi.GpuInfo(gpu_version=None, arch_name=arch, compute_capability=cc)
        add("NVIDIA L40S", "8.9", 89)
        add("NVIDIA A10G", "8.6", 86)
        for kind in ("Tesla V100-SXM2-32GB", "Tesla V100-SXM2-16GB",
                     "Tesla V100-PCIE-32GB", "Tesla V100-PCIE-16GB"):
            add(kind, "7.0", 70)
    _register_missing_gpu_kinds()
    EOF
    export PYTHONPATH="\$PWD\${PYTHONPATH:+:\$PYTHONPATH}"

    mkdir raw
    colabfold_batch \
        --model-type ${model_type} \
        ${use_esm_arg} \
        --num-recycle ${num_recycles} \
        --weights-precision ${precision} \
        --data "${params_path}" \
        $args \
        msa_in/ \
        raw/

    mapfile -t ranked_structures < <(find raw -maxdepth 1 -type f -name '*_rank_*.cif' | sort)
    if (( \${#ranked_structures[@]} == 0 )); then
        echo "COLABFOLD2_INFERENCE produced no ranked mmCIF structures" >&2
        exit 1
    fi
    cp "\${ranked_structures[0]}" "${meta.id}_colabfold2.cif"

    mapfile -t score_files < <(find raw -maxdepth 1 -type f -name '*_scores_rank_*.json' | sort)
    if (( \${#score_files[@]} == 0 )); then
        echo "COLABFOLD2_INFERENCE produced no confidence JSON files" >&2
        exit 1
    fi

    extract_metrics.py --name "${meta.id}" \
        --colabfold_metrics_files "\${score_files[@]}" \
        --structs "\${ranked_structures[@]}"

    msa_file=\$(find raw -maxdepth 1 -type f -name '*.a3m' -print -quit)
    if [[ -n "\$msa_file" ]]; then
        extract_metrics.py --name "${meta.id}" --paired_a3m "\$msa_file"
        mv "${meta.id}_msa.tsv" "${meta.id}_colabfold2_msa.tsv"
    elif [[ "${require_msa_output}" == "true" ]]; then
        echo "COLABFOLD2_INFERENCE received FASTA input but the MSA server produced no a3m files" >&2
        exit 1
    else
        touch "${meta.id}_colabfold2_msa.tsv"
    fi

    # Some backends or monomers do not define interface metrics. Emit empty
    # artifacts so downstream joins retain every sample.
    touch \
        "${meta.id}_1_pae.tsv" \
        "${meta.id}_ptm.tsv" \
        "${meta.id}_iptm.tsv" \
        "${meta.id}_ipsae.tsv" \
        "${meta.id}_chainwise_iptm.tsv" \
        "${meta.id}_chainwise_ipsae.tsv" \
        "${meta.id}_plddt.tsv"
    cp "${meta.id}_plddt.tsv" "${meta.id}_confidence.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold: \$(python3 -c 'import importlib.metadata; print(importlib.metadata.version("colabfold"))' 2>/dev/null || echo unknown)
        colabfold_commit: f850f0f22f007355bd264d48e9ed263d59331426
        alphafold3_colabfold: \$(python3 -c 'import importlib.metadata; print(importlib.metadata.version("alphafold3-colabfold"))' 2>/dev/null || echo unknown)
        jax: \$(python3 -c 'import jax; print(jax.__version__)' 2>/dev/null || echo unknown)
    END_VERSIONS
    """

    stub:
    """
    mkdir raw
    touch "${meta.id}_colabfold2.cif"
    touch "raw/${meta.id}_rank_001_${model_type}_seed_000_sample_0.cif"
    touch "raw/${meta.id}_scores_rank_001_${model_type}_seed_000_sample_0.json"
    touch "${meta.id}_colabfold2_msa.tsv"
    touch "${meta.id}_1_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_ipsae.tsv"
    touch "${meta.id}_chainwise_iptm.tsv"
    touch "${meta.id}_chainwise_ipsae.tsv"
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_confidence.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold: 1.6.3
        colabfold_commit: f850f0f22f007355bd264d48e9ed263d59331426
        alphafold3_colabfold: 3.1.14
        jax: unknown
    END_VERSIONS
    """
}
