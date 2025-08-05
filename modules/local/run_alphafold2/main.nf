/*
 * Run Alphafold2
 */
process RUN_ALPHAFOLD2 {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_alphafold2_standard:dev"

    input:
    tuple val(meta), path(fasta)
    val   db_preset
    val   alphafold2_model_preset
    path ('params/*')
    path ('bfd/*')
    path ('small_bfd/*')
    path ('mgnify/*')
    path ('pdb70/*')
    path ('mmcif_files')
    path ('obsolete_pdb/*')
    path ('uniref30/*')
    path ('uniref90/*')
    path ('pdb_seqres/*')
    path ('uniprot/*')

    output:
    path ("${fasta.baseName}*")
    tuple val(meta), path ("${meta.id}_alphafold2.pdb")    , emit: top_ranked_pdb
    tuple val(meta), path ("${fasta.baseName}/ranked*.pdb"), emit: pdb
    // TODO: re-label multiqc -> plddt so multiqc channel can take in all metrics
    tuple val(meta), path ("${meta.id}_plddt.tsv")         , emit: multiqc
    tuple val(meta), path ("${meta.id}_msa.tsv")           , emit: msa
    // TODO: alphafold2_model_preset == "monomer" the pae file won't exist.
    tuple val(meta), path ("${meta.id}_*_pae.tsv")         , optional: true, emit: paes
    tuple val(meta), path ("${meta.id}_ptm.tsv")           , optional: true, emit: ptms
    tuple val(meta), path ("${meta.id}_iptm.tsv")          , optional: true, emit: iptms
    path "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    // Note: --pkls ${fasta.baseName}/*.pkl redundantly processes the features.pkl file. Just providing conceptual reminder of file types for future refactor
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ALPHAFOLD2 module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    def db_preset_cmd = db_preset ? "full_dbs --bfd_database_path=./bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt --uniref30_database_path=./uniref30/${params.uniref30_prefix}" :
        "reduced_dbs --small_bfd_database_path=./small_bfd/bfd-first_non_consensus_sequences.fasta"
    if (alphafold2_model_preset == 'multimer') {
        alphafold2_model_preset += " --pdb_seqres_database_path=./pdb_seqres/pdb_seqres.txt --uniprot_database_path=./uniprot/uniprot.fasta "
    }
    else {
        alphafold2_model_preset += " --pdb70_database_path=./pdb70/pdb70 "
    }
    """
    if [ -f pdb_seqres/pdb_seqres.txt ]
        then sed -i "/^\\w*0/d" pdb_seqres/pdb_seqres.txt
    fi
    if [ -d params/alphafold_params_* ]; then ln -r -s params/alphafold_params_*/* params/; fi
    mgnify_db_path=\$(ls -v ./mgnify/mgy_clusters*.fa | tail -n 1)
    python3 /app/alphafold/run_alphafold.py \
        --fasta_paths=${fasta} \
        --model_preset=${alphafold2_model_preset} \
        --db_preset=${db_preset_cmd} \
        --output_dir=\$PWD \
        --data_dir=\$PWD \
        --uniref90_database_path=./uniref90/uniref90.fasta \
        --mgnify_database_path=\$mgnify_db_path \
        --template_mmcif_dir=./mmcif_files \
        --obsolete_pdbs_path=./obsolete_pdb/obsolete.dat \
        $args

    cp "${fasta.baseName}"/ranked_0.pdb ./"${meta.id}"_alphafold2.pdb

    extract_metrics.py --name ${meta.id} \\
        --pkls ${fasta.baseName}/features.pkl ${fasta.baseName}/*.pkl \\
        --structs ${fasta.baseName}/ranked*.pdb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_alphafold2.pdb"
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    mkdir "${fasta.baseName}"
    touch "${fasta.baseName}/ranked_0.pdb"
    touch "${fasta.baseName}/ranked_1.pdb"
    touch "${fasta.baseName}/ranked_2.pdb"
    touch "${fasta.baseName}/ranked_3.pdb"
    touch "${fasta.baseName}/ranked_4.pdb"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
