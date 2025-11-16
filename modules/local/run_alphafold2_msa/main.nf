/*
 * Run Alphafold2 MSA
 */
process RUN_ALPHAFOLD2_MSA {
    tag   "$meta.id"
    label 'process_medium'

    container "nf-core/proteinfold_alphafold2_msa:dev"

    input:
    tuple val(meta), path(fasta)
    val   db_preset
    val   alphafold2_model_preset
    val   uniref30_prefix
    path ('params/*')
    path ('bfd/*')
    path ('small_bfd/*')
    path ('mgnify/*')
    path ('pdb70/*')
    path ('pdb_mmcif/mmcif_files')
    path ('pdb_mmcif/*')
    path ('uniref30/*')
    path ('uniref90/*')
    path ('pdb_seqres/*')
    path ('uniprot/*')

    output:
    path ("${fasta.baseName}*")
    tuple val(meta), path ("${fasta.baseName}/features.pkl"), emit: features
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ALPHAFOLD2_MSA module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    def db_preset_cmd = db_preset ? "full_dbs --bfd_database_path=./bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt --uniref30_database_path=./uniref30/${uniref30_prefix}" :
        "reduced_dbs --small_bfd_database_path=./small_bfd/bfd-first_non_consensus_sequences.fasta"
    def extra_dbs = ""
    if (alphafold2_model_preset == 'multimer') {
        extra_dbs = " --pdb_seqres_database_path=./pdb_seqres/pdb_seqres.txt --uniprot_database_path=./uniprot/uniprot.fasta "
    } else {
        extra_dbs = " --pdb70_database_path=./pdb70/pdb70 "
    }
    """
    fix_obsolete.py pdb_mmcif/obsolete.dat > clean_obsolete.dat

    ## Handles multiple versions of mgnify database and selects the latest version
    mgnify_db_path=\$(ls -v ./mgnify/mgy_clusters*.fa | tail -n 1)

    python3 /app/alphafold/run_msa.py \
        --fasta_paths=${fasta} \
        --model_preset=${alphafold2_model_preset}${extra_dbs} \
        --db_preset=${db_preset_cmd} \
        --output_dir=\$PWD \
        --data_dir=\$PWD \
        --uniref90_database_path=./uniref90/uniref90.fasta \
        --mgnify_database_path=\$mgnify_db_path \
        --template_mmcif_dir=./pdb_mmcif/mmcif_files \
        --obsolete_pdbs_path=./clean_obsolete.dat \
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        alphafold2: \$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    mkdir ./"${fasta.baseName}"
    touch ./"${fasta.baseName}"/features.pkl

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        alphafold2: \$(cd /app/alphafold && git rev-parse HEAD 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
