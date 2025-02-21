/*
 * Run HelixFold3
 */
process RUN_HELIXFOLD3 {
    tag "$meta.id"
    label 'process_medium'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_HELIXFOLD3 module does not support Conda. Please use Docker / Singularity / Podman / Apptainer instead.")
    }

    container "nf-core/proteinfold_helixfold3:dev"

    input:
    tuple val(meta), path(fasta)
    path ('uniclust30/*')
    path ('*')
    path ('*')
    path ('bfd/*')
    path ('small_bfd/*')
    path ('uniprot/*')
    path ('pdb_seqres/*')
    path ('uniref90/*')
    path ('mgnify/*')
    path ('pdb_mmcif/*')
    path ('init_models/*')
    path ('maxit_src')

    output:
    path ("${meta.id}*")
    tuple val(meta), path ("${meta.id}_helixfold3.pdb") , emit: top_ranked_pdb
    tuple val(meta), path ("${meta.id}/ranked*pdb")     , emit: pdb
    tuple val(meta), path ("${meta.id}/*_msa.tsv")      , emit: msa
    tuple val(meta), path ("*_mqc.tsv")                 , emit: multiqc
    tuple val(meta), path ("${meta.id}_helixfold3.cif") , emit: main_cif
    path ("versions.yml")                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    export MAXIT_SRC="./maxit_src"
    export RCSBROOT="\$MAXIT_SRC"
    export PATH="\$MAXIT_SRC/bin:\$ENV_BIN:$PATH"
    export OBABEL_BIN="\$ENV_BIN"

    ln -s /app/helixfold3/* .

    \$ENV_BIN/python3.9 inference.py \
        --maxit_binary "\$MAXIT_SRC/bin/maxit" \
        --jackhmmer_binary_path "\$ENV_BIN/jackhmmer" \
        --hhblits_binary_path "\$ENV_BIN/hhblits" \
        --hhsearch_binary_path "\$ENV_BIN/hhsearch" \
        --kalign_binary_path "\$ENV_BIN/kalign" \
        --hmmsearch_binary_path "\$ENV_BIN/hmmsearch" \
        --hmmbuild_binary_path "\$ENV_BIN/hmmbuild" \
        --preset='reduced_dbs' \
        --bfd_database_path="./bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt" \
        --small_bfd_database_path="./small_bfd/bfd-first_non_consensus_sequences.fasta" \
        --uniclust30_database_path="./uniclust30/uniclust30_2018_08" \
        --uniprot_database_path="./uniprot/uniprot.fasta" \
        --pdb_seqres_database_path="./pdb_seqres/pdb_seqres.txt" \
        --rfam_database_path="./Rfam-14.9_rep_seq.fasta" \
        --template_mmcif_dir="./pdb_mmcif/mmcif_files" \
        --obsolete_pdbs_path="./pdb_mmcif/obsolete.dat" \
        --ccd_preprocessed_path="./ccd_preprocessed_etkdg.pkl.gz" \
        --uniref90_database_path "./uniref90/uniref90.fasta" \
        --mgnify_database_path "./mgnify/mgy_clusters_2018_12.fa" \
        --max_template_date=2024-08-14 \
        --input_json="${fasta}" \
        --output_dir="\$PWD" \
        --model_name allatom_demo \
        --init_model "./init_models/HelixFold3-240814.pdparams" \
        --infer_times 4 \
        --logging_level "ERROR" \
        --precision "bf16" \
        $args

    cp "${meta.id}"/"${meta.id}"-rank1/predicted_structure.pdb ./"${meta.id}"_helixfold3.pdb
    cp "${meta.id}"/"${meta.id}"-rank1/predicted_structure.cif ./"${meta.id}"_helixfold3.cif
    cd "${meta.id}"
    awk '{print \$6"\\t"\$11}' "${meta.id}"-rank1/predicted_structure.pdb > ranked_1_plddt.tsv
    for i in 2 3 4
        do awk '{print \$6"\\t"\$11}' "${meta.id}"-rank\$i/predicted_structure.pdb | awk '{print \$2}' > ranked_"\$i"_plddt.tsv
    done
    paste ranked_1_plddt.tsv ranked_2_plddt.tsv ranked_3_plddt.tsv ranked_4_plddt.tsv > plddt.tsv
    echo -e Positions"\\t"rank_1"\\t"rank_2"\\t"rank_3"\\t"rank_4 > header.tsv
    cat header.tsv plddt.tsv > ../"${meta.id}"_plddt_mqc.tsv
    for i in 1 2 3 4
        do cp ""${meta.id}"-rank\$i/predicted_structure.pdb" ./ranked_\$i.pdb
    done
    extract_output.py --name ${meta.id} \\
        --pkls final_features.pkl
    cd ..

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${meta.id}"_helixfold3.cif
    touch ./"${meta.id}"_helixfold3.pdb
    touch ./"${meta.id}"_plddt_mqc.tsv
    mkdir ./"${meta.id}"
    touch "${meta.id}/ranked_1.pdb"
    touch "${meta.id}/ranked_2.pdb"
    touch "${meta.id}/ranked_3.pdb"
    touch "${meta.id}/ranked_4.pdb"
    touch "${meta.id}/${meta.id}_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
