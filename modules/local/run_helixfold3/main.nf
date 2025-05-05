/*
 * Run HelixFold3
 */
process RUN_HELIXFOLD3 {
    tag "$meta.id"
    label 'process_medium'

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
    tuple val(meta), path ("*_mqc.tsv")                 , emit: multiqc
    tuple val(meta), path ("${meta.id}_helixfold3.cif") , emit: main_cif
    path ("versions.yml")                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_HELIXFOLD3 module does not support Conda. Please use Docker / Singularity / Podman / Apptainer instead.")
    }
    def args = task.ext.args ?: ''
    """
    ln -s /app/helixfold3/* .

    mamba run --name helixfold python3.9 inference.py \
        --maxit_binary "./maxit_src/bin/maxit" \
        --jackhmmer_binary_path "jackhmmer" \
        --hhblits_binary_path "hhblits" \
        --hhsearch_binary_path "hhsearch" \
        --kalign_binary_path "kalign" \
        --hmmsearch_binary_path "hmmsearch" \
        --hmmbuild_binary_path "hmmbuild" \
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
        --input_json="${fasta}" \
        --output_dir="\$PWD" \
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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
