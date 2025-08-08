/*
 * Run Alphafold2 PRED
 */
process RUN_ALPHAFOLD2_PRED {
    tag   "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_alphafold2_pred:dev"

    input:
    tuple val(meta), path(fasta)
    val   alphafold2_model_preset
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
    // TODO: do we ever really want to be dragging arounda  meta2? Can't we just augment meta fields for tracebility?
    tuple val(meta2), path(features)

    output:
    path ("${fasta.baseName}*")
    tuple val(meta), path ("${meta.id}_alphafold2.pdb")     , emit: top_ranked_pdb
    tuple val(meta), path ("${fasta.baseName}/ranked*.pdb") , emit: pdb
    tuple val(meta), path ("${meta.id}_msa.tsv")            , emit: msa
    // TODO: re-label multiqc -> plddt so multiqc channel can take in all metrics
    tuple val(meta), path ("${meta.id}_plddt.tsv")          , emit: multiqc
    // TODO: alphafold2_model_preset == "monomer" the pae file won't exist.
    tuple val(meta), path ("${meta.id}_*_pae.tsv")          , optional: true, emit: paes
    tuple val(meta), path ("${meta.id}_ptm.tsv")            , optional: true, emit: ptms
    tuple val(meta), path ("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    // Note: --pkls ${fasta.baseName}/*.pkl redundantly processes the features.pkl file. The use of input: features makes the conceptural separation clear
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ALPHAFOLD2_PRED module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    """
    if [ -d params/alphafold_params_* ]; then ln -r -s params/alphafold_params_*/* params/; fi
    python3 /app/alphafold/run_predict.py \\
        --fasta_paths=${fasta} \\
        --model_preset=${alphafold2_model_preset} \\
        --output_dir=\$PWD \\
        --data_dir=\$PWD \\
        --msa_path=${features} $args

    cp "${fasta.baseName}"/ranked_0.pdb ./"${meta.id}"_alphafold2.pdb

    extract_metrics.py --name ${meta.id} \\
        --pkls ${features} ${fasta.baseName}/*.pkl \\
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
