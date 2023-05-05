/*
 * Run Alphafold2 PRED
 */
process RUN_ALPHAFOLD2_PRED {
    tag   "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://nfcore/proteinfold_alphafold2_split:1.1.0' :
        'nfcore/proteinfold_alphafold2_split:1.1.0' }"

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
    path  msa

    output:
    path ("${fasta.baseName}*")
    path "*_mqc.tsv", emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    if [ -d params/alphafold_params_* ]; then ln -r -s params/alphafold_params_*/* params/; fi
    python3 /app/alphafold/run_predict.py \
        --fasta_paths=${fasta} \
        --model_preset=${alphafold2_model_preset} \
        --output_dir=\$PWD \
        --data_dir=\$PWD \
        --random_seed=53343 \
        --msa_path=${msa} \
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
