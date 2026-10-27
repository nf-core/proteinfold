/*
 * Run Alphafold2 PRED
 */
process RUN_ALPHAFOLD2_PRED {
    tag   "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "ghcr.io/jscgh/proteinfold_alphafold2_pred:2.1.0dev"

    input:
    tuple val(meta), path(fasta), path(features), val(alphafold2_model_preset)
    path ('params/*')

    output:
    path ("raw/**")                                        , emit: raw
    tuple val(meta), path ("${meta.id}_alphafold2.pdb")    , emit: top_ranked_pdb
    tuple val(meta), path ("raw/ranked_0.cif")             , emit: top_ranked_mmcif
    tuple val(meta), path ("raw/ranked*.pdb")              , emit: pdb
    tuple val(meta), path ("raw/ranked*.cif")              , emit: mmcif
    tuple val(meta), path ("${meta.id}_alphafold2_msa.tsv"), emit: msa
    tuple val(meta), path ("${meta.id}_plddt_mqc.tsv")     , emit: multiqc
    //Note: alphafold2_model_preset == "monomer" the pae file won't exist.
    tuple val(meta), path ("${meta.id}_*_pae.tsv")          , optional: true, emit: paes
    tuple val(meta), path ("${meta.id}_0_pae.tsv")          , optional: true, emit: pae
    tuple val(meta), path ("${meta.id}_ptm.tsv")            , optional: true, emit: ptms
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
        error("Local RUN_ALPHAFOLD2_PRED module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    """
    python3 /app/alphafold/run_predict.py \\
        --fasta_paths=${fasta} \\
        --model_preset=${alphafold2_model_preset} \\
        --output_dir=\$PWD \\
        --data_dir=\$PWD \\
        --msa_path=${features} $args

    cp "${fasta.baseName}"/ranked_0.pdb ./"${meta.id}"_alphafold2.pdb

    extract_metrics.py --name ${meta.id} \\
        --pkls ${features} ${fasta.baseName}/*.pkl \\
        --structs ${fasta.baseName}/ranked*.pdb

    touch "${meta.id}_iptm.tsv" "${meta.id}_ipsae.tsv" "${meta.id}_chainwise_iptm.tsv" "${meta.id}_chainwise_ipsae.tsv"

    mv "${meta.id}_msa.tsv" "${meta.id}_alphafold2_msa.tsv"

    # Can't use fasta.baseName to batch outputs in publishDir
    mv "${fasta.baseName}" raw/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        alphafold2: \$(python3 -c 'import ast; print(next(n.value.value for n in ast.parse(open("/app/alphafold/alphafold/version.py").read()).body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "__version__" for t in n.targets)))')
        jax: \$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null || echo "unknown")
        jaxlib: \$(python3 -c "import jaxlib; print(jaxlib.__version__)" 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_alphafold2.pdb"
    touch "${meta.id}_plddt_mqc.tsv"
    touch "${meta.id}_alphafold2_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_ipsae.tsv"
    touch "${meta.id}_chainwise_iptm.tsv"
    touch "${meta.id}_chainwise_ipsae.tsv"
    mkdir "raw/"
    touch "raw/ranked_0.pdb"
    touch "raw/ranked_1.pdb"
    touch "raw/ranked_2.pdb"
    touch "raw/ranked_3.pdb"
    touch "raw/ranked_4.pdb"
    touch "raw/ranked_0.cif"
    touch "raw/ranked_1.cif"
    touch "raw/ranked_2.cif"
    touch "raw/ranked_3.cif"
    touch "raw/ranked_4.cif"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        alphafold2: \$(python3 -c 'import ast; print(next(n.value.value for n in ast.parse(open("/app/alphafold/alphafold/version.py").read()).body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "__version__" for t in n.targets)))')
        jax: \$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null || echo "unknown")
        jaxlib: \$(python3 -c "import jaxlib; print(jaxlib.__version__)" 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
