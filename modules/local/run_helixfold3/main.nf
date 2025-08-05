/*
 * Run HelixFold3
 */
process RUN_HELIXFOLD3 {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_helixfold3:dev"

    input:
    tuple val(meta), path(fasta)
    path ('uniref30/*')
    path ('ccd_preprocessed_etkdg.pkl.gz')
    path ('Rfam-14.9_rep_seq.fasta')
    path ('bfd/*')
    path ('small_bfd/*')
    path ('uniprot/*')
    path ('pdb_seqres/*')
    path ('uniref90/*')
    path ('mgnify/*')
    path ('mmcif_files')
    path ('obsolete.dat')
    path ('init_models/*')
    path ('maxit_src')

    output:
    tuple val(meta), path ("${meta.id}_helixfold3.pdb") , emit: top_ranked_pdb
    tuple val(meta), path ("${meta.id}_helixfold3.cif") , emit: main_cif
    tuple val(meta), path ("${meta.id}-ranked*.pdb")    , emit: pdb
    tuple val(meta), path ("${meta.id}_plddt.tsv")      , emit: multiqc
    tuple val(meta), path ("${meta.id}_msa.tsv")        , emit: msa
    // If ${meta.id}-rank*/all_results.json" doesn't have PAE vales in the key, this will be empty
    tuple val(meta), path ("${meta.id}_*_pae.tsv") , emit: paes
    tuple val(meta), path ("${meta.id}_ptm.tsv")        , emit: ptms
    tuple val(meta), path ("${meta.id}_iptm.tsv")       , emit: iptms
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
    init_model_path=\$(ls ./init_models/*.pdparams | head -n 1)
    mgnify_db_path=\$(ls -v ./mgnify/mgy_clusters*.fa | tail -n 1)

    mamba run --name helixfold python3.9 /app/helixfold3/inference.py \\
        --maxit_binary "./maxit_src/bin/maxit" \\
        --jackhmmer_binary_path "jackhmmer" \\
        --hhblits_binary_path "hhblits" \\
        --hhsearch_binary_path "hhsearch" \\
        --kalign_binary_path "kalign" \\
        --hmmsearch_binary_path "hmmsearch" \\
        --hmmbuild_binary_path "hmmbuild" \\
        --nhmmer_binary_path "nhmmer" \\
        --bfd_database_path="./bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt" \\
        --small_bfd_database_path="./small_bfd/bfd-first_non_consensus_sequences.fasta" \\
        --uniclust30_database_path="./uniref30/${params.uniref30_prefix}" \\
        --uniprot_database_path="./uniprot/uniprot.fasta" \\
        --pdb_seqres_database_path="./pdb_seqres/pdb_seqres.txt" \\
        --rfam_database_path="./Rfam-14.9_rep_seq.fasta" \\
        --template_mmcif_dir="./mmcif_files" \\
        --obsolete_pdbs_path="./obsolete.dat" \\
        --ccd_preprocessed_path="./ccd_preprocessed_etkdg.pkl.gz" \\
        --uniref90_database_path "./uniref90/uniref90.fasta" \\
        --mgnify_database_path "\$mgnify_db_path" \\
        --input_json="${fasta}" \\
        --output_dir="\$PWD" \\
        --init_model "\$init_model_path" \\
        $args

    cp "${fasta.baseName}/${fasta.baseName}-rank1/predicted_structure.pdb" "./${meta.id}_helixfold3.pdb"
    cp "${fasta.baseName}/${fasta.baseName}-rank1/predicted_structure.cif" "./${meta.id}_helixfold3.cif"

    mamba run --name helixfold extract_metrics.py --name ${meta.id} \\
        --structs ${fasta.baseName}/${fasta.baseName}-rank*/predicted_structure.pdb \\
        --pkls "${fasta.baseName}/final_features.pkl" \\
        --jsons ${fasta.baseName}/${fasta.baseName}-rank*/all_results.json

    [ ! -d ${meta.id} ] && mkdir ${meta.id}
    for i in 1 2 3 4 5; do
        cp "${fasta.baseName}/${fasta.baseName}-rank\$i/predicted_structure.pdb" "${meta.id}-ranked_\$i.pdb"

    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_helixfold3.cif"
    touch "${meta.id}_helixfold3.pdb"
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_msa.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_1_pae.tsv"
    touch "${meta.id}_2_pae.tsv"
    touch "${meta.id}_3_pae.tsv"
    touch "${meta.id}_4_pae.tsv"
    touch "${meta.id}_5_pae.tsv"
    mkdir "${meta.id}"
    touch "${meta.id}-ranked_1.pdb"
    touch "${meta.id}-ranked_2.pdb"
    touch "${meta.id}-ranked_3.pdb"
    touch "${meta.id}-ranked_4.pdb"
    touch "${meta.id}-ranked_5.pdb"


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
