/*
 * Run Alphafold2
 */
process RUN_AF2 {
    tag "${seq_name}"
    label 'customConf'

    //TODO
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/af2_proteinfold:v0.6' :
        'athbaltzis/af2_proteinfold:v0.6' }"

    input:
    tuple val(seq_name), path(fasta)
    val   max_template_date
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
    cp params/alphafold_params_*/* params/
    python3 /app/alphafold/run_alphafold.py \
        --fasta_paths=${fasta} \
        --max_template_date=${max_template_date} \
        --model_preset=${model_preset} \
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
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${fasta.baseName}".alphafold.pdb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
