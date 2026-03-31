/*
 * Run Alphafold3
 */
process RUN_ALPHAFOLD3 {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'
    container "nf-core/proteinfold_alphafold3_standard:2.0.0"

    input:
    tuple val(meta), path(json)
    path "params/*"
    path "small_bfd/*"
    path "mgnify/*"
    path "mmcif_files"
    path "uniref90/*"
    path "pdb_seqres/*"
    path "uniprot/*"

    output:
    path ("raw/**")                                         , emit: raw
    tuple val(meta), path ("${meta.id}_alphafold3.cif")     , emit: top_ranked_cif
    tuple val(meta), path ("raw/*ranked_*.cif")             , emit: cif
    tuple val(meta), path ("${meta.id}_plddt.tsv")          , emit: plddt
    tuple val(meta), path ("${meta.id}_alphafold3_msa.tsv") , emit: msa
    tuple val(meta), path ("${meta.id}_0_pae.tsv")          , emit: pae
    tuple val(meta), path ("${meta.id}_ptm.tsv")            , emit: ptms
    tuple val(meta), path ("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ALPHAFOLD3 module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def af3_id = meta.id.toLowerCase()
    """
    # Check database files exist and set variables
    pdb_seqres=\$(ls -v ./pdb_seqres/pdb_seqres.txt ./pdb_seqres/pdb_seqres_2022_09_28.fasta 2>/dev/null | tail -n 1 || echo "")
    if [[ -z "\$pdb_seqres" ]]; then
        echo "ERROR: No pdb_seqres file found"
        exit 1
    fi

    uniref90=\$(ls -v ./uniref90/uniref90*.fa ./uniref90/uniref90*.fasta 2>/dev/null | tail -n 1 || echo "")
    if [[ -z "\$uniref90" ]]; then
        echo "ERROR: No uniref90 file found"
        exit 1
    fi

    mgnify=\$(ls -v ./mgnify/mgy_clusters*.fa ./mgnify/mgnify_clusters*.fasta 2>/dev/null | tail -n 1 || echo "")
    if [[ -z "\$mgnify" ]]; then
        echo "ERROR: No mgnify file found"
        exit 1
    fi

    uniprot=\$(ls -v ./uniprot/uniprot.fasta ./uniprot/uniprot*.fa 2>/dev/null | tail -n 1 || echo "")
    if [[ -z "\$uniprot" ]]; then
        echo "ERROR: No uniprot file found"
        exit 1
    fi

    python3 /app/alphafold/run_alphafold.py \\
        --json_path=${json} \\
        --model_dir=./params \\
        --uniref90_database_path=\$uniref90 \\
        --mgnify_database_path=\$mgnify \\
        --pdb_database_path=./mmcif_files \\
        --small_bfd_database_path=./small_bfd/bfd-first_non_consensus_sequences.fasta \\
        --uniprot_cluster_annot_database_path=\$uniprot \\
        --seqres_database_path=\$pdb_seqres \\
        --output_dir=\$PWD \\
        $args

    ### Move the rest of the models and rename them according to their rank
    name=\$(jq -r '.name' ${json})

    ## Copy top ranked model to root
    cp -n "\${name}/\${name}_model.cif" "${prefix}_alphafold3.cif"

    ## Sort the rows by ranking_score in descending order
    sorted_csv=\$(head -n 1 "\${name}/ranking_scores.csv"; tail -n +2 "\${name}/ranking_scores.csv" | sort -t, -k3 -nr)
    rank=0

    ## Create raw directory for intermediate files
    mkdir -p raw

    ## Generate files with rank tag in raw directory
    echo "\$sorted_csv" | tail -n +2 | while IFS=',' read -r seed sample ranking_score; do
    cp -n "\${name}/seed-\${seed}_sample-\${sample}/model.cif" "raw/seed_\${seed}_sample_\${sample}_ranked_\${rank}.cif"
    rank=\$((rank + 1))
    done

    extract_metrics.py --name ${prefix} \\
        --jsons ${af3_id}/${af3_id}_data.json ${af3_id}/${af3_id}_summary_confidences.json ${af3_id}/${af3_id}_confidences.json \\
        --structs raw/*ranked_*.cif

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
        hmmer: \$(hmmsearch -h | grep -o '^# HMMER [0-9.]*' | sed 's/^# HMMER //' || echo "unknown")
        rdkit: \$(python3 -c "import rdkit; print(rdkit.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p raw
    touch ${prefix}_alphafold3.cif
    touch raw/${prefix}_ranked_1.cif
    touch raw/${prefix}_ranked_2.cif
    touch raw/${prefix}_ranked_3.cif
    touch raw/${prefix}_ranked_4.cif
    touch raw/${prefix}_ranked_5.cif
    touch ${prefix}_plddt.tsv
    touch ${prefix}_alphafold3_msa.tsv
    touch ${prefix}_0_pae.tsv
    touch ${prefix}_ptm.tsv
    touch ${prefix}_iptm.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        alphafold3: \$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
        jax: \$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null || echo "unknown")
        jaxlib: \$(python3 -c "import jaxlib; print(jaxlib.__version__)" 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
        hmmer: \$(hmmsearch -h | grep -o '^# HMMER [0-9.]*' | sed 's/^# HMMER //')
        rdkit: \$(python3 -c "import rdkit; print(rdkit.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
