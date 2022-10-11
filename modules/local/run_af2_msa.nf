/*
 * Run Alphafold2 MSA
 */
process RUN_AF2_MSA {
    tag "${seq_name}"
    label 'customConf'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://luisas/af2_msa:v0.1' :
        'luisas/af2_msa:v0.1' }"

    input:
    tuple val(seq_name), path(fasta)
    val   db_preset
    val   model_preset
    path ('params/*')
    path ('bfd/*')
    path ('small_bfd/*')
    path ('mgnify/*')
    path ('pdb70/*')
    path ('pdb_mmcif/*')
    path ('uniclust30/*')
    path ('uniref90/*')
    path ('pdb_seqres/*')
    path ('uniprot/*')

    output:
    path ("${fasta.baseName}*")
    path ("${fasta.baseName}.features.pkl"), emit: features
    path "versions.yml" , emit: versions

    script:
    def args = task.ext.args ?: ''
    def db_preset = db_preset ? "full_dbs --bfd_database_path=./bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt --uniclust30_database_path=./uniclust30/uniclust30_2018_08/uniclust30_2018_08" :
        "reduced_dbs --small_bfd_database_path=./small_bfd/bfd-first_non_consensus_sequences.fasta"
    if (model_preset == 'multimer') {
        model_preset = model_preset + " --pdb_seqres_database_path=./pdb_seqres/pdb_seqres.txt --uniprot_database_path=./uniprot/uniprot.fasta "
    }
    else {
        model_preset = model_preset + " --pdb70_database_path=./pdb70/pdb70_from_mmcif_200916/pdb70 "
    }
    """
    python3 /app/alphafold/run_msa.py \
        --fasta_paths=${fasta} \
        --model_preset=${model_preset} \
        --db_preset=${db_preset} \
        --output_dir=\$PWD \
        --data_dir=\$PWD \
        --uniref90_database_path=./uniref90/uniref90.fasta \
        --mgnify_database_path=./mgnify/mgy_clusters_2018_12.fa \
        --template_mmcif_dir=./pdb_mmcif/mmcif_files \
        --obsolete_pdbs_path=./pdb_mmcif/obsolete.dat  \
        $args

    cp "${fasta.baseName}"/features.pkl ./"${fasta.baseName}".features.pkl

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${fasta.baseName}".features.pkl

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
