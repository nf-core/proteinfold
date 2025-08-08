/*
 * Run Alphafold3
 */
process RUN_ALPHAFOLD3 {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_alphafold3_standard:1.2.0dev"

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
    tuple val(meta), path ("publish/*top_ranked.cif"), emit: top_ranked_cif
    tuple val(meta), path ("publish/*ranked_*.cif")  , emit: cif
    tuple val(meta), path ("${meta.id}_plddt.tsv")   , emit: multiqc
    tuple val(meta), path ("${meta.id}_msa.tsv")     , emit: msa
    path "versions.yml"                              , emit: versions

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
    if [ -f pdb_seqres/pdb_seqres.txt ]
    then
        sed -i "/^\\w*0/d" pdb_seqres/pdb_seqres.txt
    fi

    python3 /app/alphafold/run_alphafold.py \\
        --json_path=${json} \\
        --model_dir=./params \\
        --uniref90_database_path=./uniref90/uniref90_2022_05.fa \\
        --mgnify_database_path=./mgnify/mgy_clusters_2022_05.fa \\
        --pdb_database_path=./mmcif_files \\
        --small_bfd_database_path=./small_bfd/bfd-first_non_consensus_sequences.fasta \\
        --uniprot_cluster_annot_database_path=./uniprot/uniprot_all_2021_04.fa \\
        --seqres_database_path=./pdb_seqres/pdb_seqres_2022_09_28.fasta \\
        --output_dir=\$PWD \\
        $args

    ## Rename the top ranked model
    if [ ! -d publish ]; then
        mkdir -p publish
    fi

    ## Move the rest of the models and rename them according to their rank
    name=\$(jq -r '.name' ${json})
    cp -n "\${name}/\${name}_model.cif" "publish/${prefix}_top_ranked.cif"

    # Sort the rows by ranking_score in descending order
    sorted_csv=\$(head -n 1 "\${name}/ranking_scores.csv"; tail -n +2 "\${name}/ranking_scores.csv" | sort -t, -k3 -nr)

    rank=0
    touch publish/combined_plddt_mqc.tsv

    # Generate files with rank tag
    echo "\$sorted_csv" | tail -n +2 | while IFS=',' read -r seed sample ranking_score; do
    cp -n "\${name}/seed-\${seed}_sample-\${sample}/model.cif" "publish/seed_\${seed}_sample_\${sample}_ranked_\${rank}.cif"
    rank=\$((rank + 1))
    done

    extract_metrics.py --name ${prefix} \\
        --jsons ${af3_id}/${af3_id}_data.json \\
        --structs publish/*ranked_*.cif

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir publish
    touch publish/${prefix}_top_ranked.cif
    touch publish/${prefix}_ranked_1.cif
    touch publish/${prefix}_ranked_2.cif
    touch publish/${prefix}_ranked_3.cif
    touch publish/${prefix}_ranked_4.cif
    touch publish/${prefix}_ranked_5.cif
    touch ${prefix}_plddt.tsv
    touch ${prefix}_msa.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
