/*
 * Run Alphafold2 PRED
 */
process RUN_AF2_PRED {
    tag "${seq_name}"
    label 'customConf'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://luisas/af2_split:v.1.0' :
        'luisas/af2_split:v.1.0' }"

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
    path  msa

    output:
    path ("${fasta.baseName}*")

    script:
    def args = task.ext.args ?: ''
    """
    cp params/alphafold_params_*/* params/
    python3 /app/alphafold/run_predict.py \
        --fasta_paths=${fasta} \
        --model_preset=${model_preset} \
        --output_dir=\$PWD \
        --data_dir=\$PWD \
        --random_seed=53343 \
        --msa_path=${msa} \
        $args

    cp "${fasta.baseName}"/ranked_0.pdb ./"${fasta.baseName}".alphafold.pdb
    """

    stub:
    """
    touch ./"${fasta.baseName}".alphafold.pdb
    """
}
