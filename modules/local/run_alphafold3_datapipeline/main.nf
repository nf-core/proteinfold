/*
 * Run AlphaFold3 data pipeline (MSA + template search only, no inference)
 */
process RUN_ALPHAFOLD3_DATAPIPELINE {
    tag "$meta.id"
    label 'process_medium'
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
    tuple val(meta), path ("${meta.id}_data.json"), emit: data_json
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ALPHAFOLD3_DATAPIPELINE module does not support Conda. Please use Docker / Singularity / Podman instead.")
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
        --run_data_pipeline=true \\
        --run_inference=false \\
        $args

    cp ${af3_id}/${af3_id}_data.json ${prefix}_data.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        alphafold3: \$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
        hmmer: \$(hmmsearch -h | grep -o '^# HMMER [0-9.]*' | sed 's/^# HMMER //' || echo "unknown")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_data.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        alphafold3: \$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
        hmmer: \$(hmmsearch -h | grep -o '^# HMMER [0-9.]*' | sed 's/^# HMMER //' || echo "unknown")
    END_VERSIONS
    """
}
