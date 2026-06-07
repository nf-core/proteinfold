/*
 * Run AlphaFold3 inference only (structure prediction from pre-computed MSA/templates)
 */
process RUN_ALPHAFOLD3_INFERENCE {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'
    container "nf-core/proteinfold_alphafold3_standard:2.0.0"

    input:
    tuple val(meta), path(data_json)
    path "params/*"

    output:
    path ("raw/**")                                         , emit: raw
    tuple val(meta), path ("${meta.id}_alphafold3.cif")     , emit: top_ranked_cif
    tuple val(meta), path ("raw/*ranked_*.cif")             , emit: cif
    tuple val(meta), path ("${meta.id}_plddt_mqc.tsv")      , emit: multiqc
    tuple val(meta), path ("${meta.id}_alphafold3_msa.tsv") , emit: msa
    tuple val(meta), path ("${meta.id}_0_pae.tsv")          , emit: pae
    tuple val(meta), path ("${meta.id}_ptm.tsv")            , emit: ptms
    tuple val(meta), path ("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    tuple val(meta), path ("${meta.id}_ipsae.tsv")          , optional: true, emit: ipsaes
    tuple val(meta), path ("${meta.id}_chainwise_iptm.tsv") , optional: true, emit: chainwise_iptms
    tuple val(meta), path ("${meta.id}_chainwise_ipsae.tsv"), optional: true, emit: chainwise_ipsaes
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ALPHAFOLD3_INFERENCE module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def af3_id = meta.id.toLowerCase()
    """
    # Stage pre-computed data JSON where AlphaFold3 expects it so it is not regenerated
    mkdir -p ${af3_id}
    cp ${data_json} ${af3_id}/${af3_id}_data.json

    python3 /app/alphafold/run_alphafold.py \\
        --json_path=${data_json} \\
        --model_dir=./params \\
        --output_dir=\$PWD \\
        --run_data_pipeline=false \\
        --run_inference=true \\
        $args

    ### Move the rest of the models and rename them according to their rank
    name=\$(jq -r '.name' ${data_json})

    ## Copy top ranked model to root
    cp -n "\${name}/\${name}_model.cif" "${prefix}_alphafold3.cif"

    ## Sort the rows by ranking_score in descending order
    sorted_csv=\$(head -n 1 "\${name}/ranking_scores.csv"; tail -n +2 "\${name}/ranking_scores.csv" | sort -t, -k3 -nr)
    rank=0

    ## Create raw directory for intermediate files
    mkdir -p raw

    ## Generate files with rank tag in raw directory
    echo "\$sorted_csv" | tail -n +2 | while IFS=',' read -r seed sample ranking_score; do
        cp -n "\${name}/seed-\${seed}_sample-\${sample}/model.cif" "raw/ranked_\${rank}_seed_\${seed}_sample_\${sample}.cif"
        rank=\$((rank + 1))
    done

    extract_metrics.py --name ${prefix} \\
        --jsons ${af3_id}/${af3_id}_data.json ${af3_id}/${af3_id}_summary_confidences.json ${af3_id}/${af3_id}_confidences.json \\
        --structs raw/*ranked_*.cif

    touch "${prefix}_iptm.tsv" "${prefix}_ipsae.tsv" "${prefix}_chainwise_iptm.tsv" "${prefix}_chainwise_ipsae.tsv"

    mv "${prefix}_msa.tsv" "${meta.id}_alphafold3_msa.tsv"

    ## Move alphafold3 output directory to raw for save_intermediates
    mv \${name}/* raw/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        alphafold3: \$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
        jax: \$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null || echo "unknown")
        jaxlib: \$(python3 -c "import jaxlib; print(jaxlib.__version__)" 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
        rdkit: \$(python3 -c "import rdkit; print(rdkit.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p raw
    touch ${prefix}_alphafold3.cif
    touch raw/ranked_0_${prefix}.cif
    touch raw/ranked_1_${prefix}.cif
    touch raw/ranked_2_${prefix}.cif
    touch raw/ranked_3_${prefix}.cif
    touch raw/ranked_4_${prefix}.cif
    touch ${prefix}_plddt_mqc.tsv
    touch ${prefix}_alphafold3_msa.tsv
    touch ${prefix}_0_pae.tsv
    touch ${prefix}_ptm.tsv
    touch ${prefix}_iptm.tsv
    touch ${prefix}_ipsae.tsv
    touch ${prefix}_chainwise_iptm.tsv
    touch ${prefix}_chainwise_ipsae.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        alphafold3: \$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
        jax: \$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null || echo "unknown")
        jaxlib: \$(python3 -c "import jaxlib; print(jaxlib.__version__)" 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
        rdkit: \$(python3 -c "import rdkit; print(rdkit.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
