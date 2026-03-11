/*
 * Run Alphafold2 PRED
 */
process RUN_ALPHAFOLD2_PRED {
    tag   "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_alphafold2_pred:2.0.0"

    input:
    tuple val(meta), path(fasta), path(features), val(alphafold2_model_preset)
    path ('params/*')
    path ('bfd/*')
    path ('small_bfd/*')
    path ('mgnify/*')
    path ('pdb70/*')
    path ('pdb_mmcif/mmcif_files')
    path ('pdb_mmcif/*')
    path ('uniref30/*')
    path ('uniref90/*')
    path ('pdb_seqres/*')
    path ('uniprot/*')

    output:
    tuple val(meta), path ("raw/**")                         , emit: raw
    tuple val(meta), path ("${meta.id}_alphafold2.pdb")     , emit: top_ranked_pdb
    tuple val(meta), path ("raw/ranked*.pdb")               , emit: pdb
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

    # Can't use fasta.baseName to batch outputs in publishDir
    mv "${fasta.baseName}" raw/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        alphafold2: \$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
        jax: \$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null || echo "unknown")
        jaxlib: \$(python3 -c "import jaxlib; print(jaxlib.__version__)" 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_alphafold2.pdb"
    mkdir "raw/"
    touch "raw/ranked_0.pdb"
    touch "raw/ranked_1.pdb"
    touch "raw/ranked_2.pdb"
    touch "raw/ranked_3.pdb"
    touch "raw/ranked_4.pdb"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        alphafold2: \$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
        jax: \$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null || echo "unknown")
        jaxlib: \$(python3 -c "import jaxlib; print(jaxlib.__version__)" 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
