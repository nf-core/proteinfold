process RUN_ESMFOLD2 {
    //maxForks 1
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    //container "nf-core/proteinfold_esmfold2:2.0.0"
    container "ghcr.io/jscgh/proteinfold_esmfold2:0.1.0"

    input:
    tuple val(meta), path(input_seq), path(msa_csv)
    path(esmfold2_weights)

    output:
    tuple val(meta), path ("${meta.id}_esmfold2.cif")    , emit: top_ranked_pdb
    tuple val(meta), path ("*.cif")                       , emit: cif
    tuple val(meta), path ("${meta.id}_esmfold2_msa.tsv") , emit: msa_raw
    tuple val(meta), path ("${meta.id}_0_pae.tsv")        , emit: pae_raw
    tuple val(meta), path ("${meta.id}_ptm.tsv")          , emit: ptm_raw
    tuple val(meta), path ("${meta.id}_iptm.tsv")         , emit: iptm_raw
    tuple val(meta), path ("${meta.id}_chainwise_iptm.tsv"), emit: chainwise_iptm_raw
    path "versions.yml"                                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ESMFOLD2 module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    def args = task.ext.args ?: ''

    """
    export HF_HOME="${esmfold2_weights}"
    export TRITON_CACHE_DIR="$PWD/.triton"
    export TORCHINDUCTOR_CACHE_DIR="$PWD/.torchinductor"
    export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

    run_esmfold2.py \\
        --input ${input_seq} \\
        --id ${meta.id} \\
        --output_dir . \\
        --output_format both \\
        --num-loops 20 \\
        $args

    if [ -f "${meta.id}.cif" ]; then
        cp "${meta.id}.cif" "${meta.id}_esmfold2.cif"
    fi

    if [ -f "${meta.id}_esmfold2_msa.tsv" ]; then
        :
    else
        if [ -f "${msa_csv}" ]; then
            cp "${msa_csv}" "${meta.id}_esmfold2_msa.tsv"
        else
            touch "${meta.id}_esmfold2_msa.tsv"
        fi
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        pytorch: \$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
        transformers: \$(python3 -c "import transformers; print(transformers.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_esmfold2.cif"
    touch "${meta.id}_esmfold2_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_chainwise_iptm.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        pytorch: \$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
        transformers: \$(python3 -c "import transformers; print(transformers.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
