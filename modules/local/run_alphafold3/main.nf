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
    path("raw/**")                                          , emit: raw
    tuple val(meta), path("${meta.id}_alphafold3.cif")      , emit: top_ranked_cif
    tuple val(meta), path("raw/*ranked_*.cif")              , emit: cif
    tuple val(meta), path("${meta.id}_plddt.tsv")           , emit: multiqc
    tuple val(meta), path("${meta.id}_alphafold3_msa.tsv")  , emit: msa
    tuple val(meta), path("${meta.id}_0_pae.tsv")           , emit: pae
    tuple val(meta), path("${meta.id}_ptm.tsv")             , emit: ptms
    tuple val(meta), path("${meta.id}_iptm.tsv")            , optional: true, emit: iptms
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

    """
    set -euo pipefail

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
        --uniref90_database_path="\$uniref90" \\
        --mgnify_database_path="\$mgnify" \\
        --pdb_database_path=./mmcif_files \\
        --small_bfd_database_path=./small_bfd/bfd-first_non_consensus_sequences.fasta \\
        --uniprot_cluster_annot_database_path="\$uniprot" \\
        --seqres_database_path="\$pdb_seqres" \\
        --output_dir="\$PWD" \\
        ${args}

    # AlphaFold3 output directory/name from the input JSON
    name=\$(jq -r '.name' ${json})

    if [[ -z "\$name" || "\$name" == "null" ]]; then
        echo "ERROR: Could not read .name from input JSON: ${json}"
        exit 1
    fi

    if [[ ! -d "\$name" ]]; then
        echo "ERROR: AlphaFold3 output directory not found: \$name"
        echo "Current directory contents:"
        find . -maxdepth 2 \\( -type f -o -type d \\) | sort
        exit 1
    fi

    # Expected AlphaFold3 v3 output naming:
    # output_dir/name_model.cif
    # output_dir/name_ranking_scores.csv
    # output_dir/name_data.json
    # output_dir/name_summary_confidences.json
    # output_dir/name_confidences.json
    # output_dir/seed-SEED_sample-SAMPLE/name_seed-SEED_sample-SAMPLE_model.cif

    model_cif="\${name}/\${name}_model.cif"
    ranking_scores="\${name}/\${name}_ranking_scores.csv"
    data_json="\${name}/\${name}_data.json"
    summary_confidences_json="\${name}/\${name}_summary_confidences.json"
    confidences_json="\${name}/\${name}_confidences.json"

    if [[ ! -f "\$model_cif" ]]; then
        echo "ERROR: Could not find AlphaFold3 model CIF: \$model_cif"
        find "\${name}" -maxdepth 3 -type f | sort
        exit 1
    fi

    if [[ ! -f "\$ranking_scores" ]]; then
        echo "ERROR: Could not find AlphaFold3 ranking scores CSV: \$ranking_scores"
        find "\${name}" -maxdepth 3 -type f | sort
        exit 1
    fi

    if [[ ! -f "\$data_json" ]]; then
        echo "ERROR: Could not find AlphaFold3 data JSON: \$data_json"
        find "\${name}" -maxdepth 3 -type f | sort
        exit 1
    fi

    if [[ ! -f "\$summary_confidences_json" ]]; then
        echo "ERROR: Could not find AlphaFold3 summary confidences JSON: \$summary_confidences_json"
        find "\${name}" -maxdepth 3 -type f | sort
        exit 1
    fi

    if [[ ! -f "\$confidences_json" ]]; then
        echo "ERROR: Could not find AlphaFold3 confidences JSON: \$confidences_json"
        find "\${name}" -maxdepth 3 -type f | sort
        exit 1
    fi

    # Copy top-ranked model to root
    cp "\$model_cif" "${prefix}_alphafold3.cif"

    # Sort rows by ranking_score in descending order.
    # Expected CSV columns: seed,sample,ranking_score
    sorted_csv=\$(head -n 1 "\$ranking_scores"; tail -n +2 "\$ranking_scores" | sort -t, -k3 -nr)

    # Create raw directory for intermediate files
    mkdir -p raw

    # Generate ranked CIF files for nf-core output.
    # Also generate ranked PDB files for extract_metrics.py, which expects PDB.
    rank=0
    echo "\$sorted_csv" | tail -n +2 | while IFS=',' read -r seed sample ranking_score; do
        sample_dir="\${name}/seed-\${seed}_sample-\${sample}"
        sample_cif="\${sample_dir}/\${name}_seed-\${seed}_sample-\${sample}_model.cif"

        if [[ ! -f "\$sample_cif" ]]; then
            echo "ERROR: Expected sample CIF not found: \$sample_cif"
            find "\${name}" -maxdepth 3 -type f | sort
            exit 1
        fi

        ranked_cif="raw/seed_\${seed}_sample_\${sample}_ranked_\${rank}.cif"
        ranked_pdb="raw/seed_\${seed}_sample_\${sample}_ranked_\${rank}.pdb"

        cp "\$sample_cif" "\$ranked_cif"

        python3 - <<PY
from Bio.PDB import MMCIFParser, PDBIO

parser = MMCIFParser(QUIET=True)
structure = parser.get_structure("model", "\$ranked_cif")

io = PDBIO()
io.set_structure(structure)
io.save("\$ranked_pdb")
PY

        rank=\$((rank + 1))
    done

    extract_metrics.py --name ${prefix} \\
        --jsons "\$data_json" "\$summary_confidences_json" "\$confidences_json" \\
        --structs raw/*ranked_*.pdb

    mv "${prefix}_msa.tsv" "${meta.id}_alphafold3_msa.tsv"

    # Move AlphaFold3 output directory contents to raw for save_intermediates
    mv "\${name}"/* raw/

    python_version=\$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
    alphafold3_version=\$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
    jax_version=\$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null || echo "unknown")
    jaxlib_version=\$(python3 -c "import jaxlib; print(jaxlib.__version__)" 2>/dev/null || echo "unknown")
    numpy_version=\$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    biopython_version=\$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    hmmer_version=\$(hmmsearch -h 2>/dev/null | grep -o '^# HMMER [0-9.]*' | sed 's/^# HMMER //' || echo "unknown")
    rdkit_version=\$(python3 -c "import rdkit; print(rdkit.__version__)" 2>/dev/null || echo "unknown")

    printf '%s\\n' \\
        '"${task.process}":' \\
        "    python: \${python_version}" \\
        "    alphafold3: \${alphafold3_version}" \\
        "    jax: \${jax_version}" \\
        "    jaxlib: \${jaxlib_version}" \\
        "    numpy: \${numpy_version}" \\
        "    biopython: \${biopython_version}" \\
        "    hmmer: \${hmmer_version}" \\
        "    rdkit: \${rdkit_version}" \\
        > versions.yml
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

    python_version=\$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
    alphafold3_version=\$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
    jax_version=\$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null || echo "unknown")
    jaxlib_version=\$(python3 -c "import jaxlib; print(jaxlib.__version__)" 2>/dev/null || echo "unknown")
    numpy_version=\$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    biopython_version=\$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    hmmer_version=\$(hmmsearch -h 2>/dev/null | grep -o '^# HMMER [0-9.]*' | sed 's/^# HMMER //' || echo "unknown")
    rdkit_version=\$(python3 -c "import rdkit; print(rdkit.__version__)" 2>/dev/null || echo "unknown")

    printf '%s\\n' \\
        '"${task.process}":' \\
        "    python: \${python_version}" \\
        "    alphafold3: \${alphafold3_version}" \\
        "    jax: \${jax_version}" \\
        "    jaxlib: \${jaxlib_version}" \\
        "    numpy: \${numpy_version}" \\
        "    biopython: \${biopython_version}" \\
        "    hmmer: \${hmmer_version}" \\
        "    rdkit: \${rdkit_version}" \\
        > versions.yml
    """
}
