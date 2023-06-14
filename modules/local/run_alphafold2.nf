/*
 * Run Alphafold2
 */
process RUN_ALPHAFOLD2 {
    tag "$meta.id"
    label 'process_medium'

    container "nf-core/proteinfold_alphafold2_standard:1.1.0"

    input:
    tuple val(meta), path(fasta)
    val   db_preset
    val   alphafold2_model_preset
    path ('params/*')
    path ('bfd/*')
    path ('small_bfd/*')
    path ('mgnify/*')
    path ('pdb70/*')
    path ('pdb_mmcif/*')
    path ('uniref30/*')
    path ('uniref90/*')
    path ('pdb_seqres/*')
    path ('uniprot/*')

    output:
    path ("${fasta.baseName}*")
    path "*_mqc.tsv", emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def db_preset = db_preset ? "full_dbs --bfd_database_path=./bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt --uniref30_database_path=./uniref30/UniRef30_2021_03" :
        "reduced_dbs --small_bfd_database_path=./small_bfd/bfd-first_non_consensus_sequences.fasta"
    if (alphafold2_model_preset == 'multimer') {
        alphafold2_model_preset += " --pdb_seqres_database_path=./pdb_seqres/pdb_seqres.txt --uniprot_database_path=./uniprot/uniprot.fasta "
    }
    else {
        alphafold2_model_preset += " --pdb70_database_path=./pdb70/pdb70_from_mmcif_200916/pdb70 "
    }
    """
    if [ -f pdb_seqres/pdb_seqres.txt ]
        then sed -i "/^\\w*0/d" pdb_seqres/pdb_seqres.txt
    fi
    if [ -d params/alphafold_params_* ]; then ln -r -s params/alphafold_params_*/* params/; fi
    python3 /app/alphafold/run_alphafold.py \
        --fasta_paths=${fasta} \
        --model_preset=${alphafold2_model_preset} \
        --db_preset=${db_preset} \
        --output_dir=\$PWD \
        --data_dir=\$PWD \
        --uniref90_database_path=./uniref90/uniref90.fasta \
        --mgnify_database_path=./mgnify/mgy_clusters_2018_12.fa \
        --template_mmcif_dir=./pdb_mmcif/mmcif_files \
        --obsolete_pdbs_path=./pdb_mmcif/obsolete.dat \
        --random_seed=53343 \
        $args

    cp "${fasta.baseName}"/ranked_0.pdb ./"${fasta.baseName}".alphafold.pdb
    cd "${fasta.baseName}"
    awk '{print \$6"\\t"\$11}' ranked_0.pdb | uniq > ranked_0_plddt.tsv
    for i in 1 2 3 4
        do awk '{print \$6"\\t"\$11}' ranked_\$i.pdb | uniq | awk '{print \$2}' > ranked_"\$i"_plddt.tsv
    done
    paste ranked_0_plddt.tsv ranked_1_plddt.tsv ranked_2_plddt.tsv ranked_3_plddt.tsv ranked_4_plddt.tsv > plddt.tsv
    echo -e Positions"\\t"rank_0"\\t"rank_1"\\t"rank_2"\\t"rank_3"\\t"rank_4 > header.tsv
    cat header.tsv plddt.tsv > ../"${fasta.baseName}"_plddt_mqc.tsv
    cd ..

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${fasta.baseName}".alphafold.pdb
    touch ./"${fasta.baseName}"_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
