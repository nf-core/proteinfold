process COLABFOLD_BATCH {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_colabfold:dev"

    input:
    tuple val(meta), path(fasta)
    val   colabfold_model_preset
    path  ('params/*')
    path  ('colabfold_db/*')
    path  ('uniref30/*')
    val   numRec

    output:
    tuple val(meta), path ("${meta.id}_colabfold.pdb"), emit: top_ranked_pdb
    tuple val(meta), path ("*relaxed_rank_*.pdb")     , emit: pdb
    tuple val(meta), path ("*_coverage.png")          , emit: msa
    tuple val(meta), path ("*_mqc.png")               , emit: multiqc
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local COLABFOLD_BATCH module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''

    """
    ln -s \$(realpath params/alphafold_params_*/*) params/
    touch params/download_finished.txt

    colabfold_batch \\
        $args \\
        --num-recycle ${numRec} \\
        --data \$PWD \\
        --model-type ${colabfold_model_preset} \\
        ${fasta} \\
        \$PWD
    for i in `find *.png -maxdepth 0`; do cp \$i \${i%'.png'}_mqc.png; done
    if [ ! -e `find *_relaxed_rank_001_*.pdb` ]; then
        cp *_relaxed_rank_001*.pdb ${meta.id}_colabfold.pdb
    else
        cp *_unrelaxed_rank_001*.pdb ${meta.id}_colabfold.pdb
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold_batch: \$(conda run -n colabfold pip list | grep "^colabfold" | awk '{print \$2}')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${meta.id}"_colabfold.pdb
    touch ./"${meta.id}"_mqc.png
    touch ./${meta.id}_relaxed_rank_01.pdb
    touch ./${meta.id}_relaxed_rank_02.pdb
    touch ./${meta.id}_relaxed_rank_03.pdb
    touch ./${meta.id}_coverage.png
    touch ./${meta.id}_scores_rank.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold_batch: \$(conda run -n colabfold pip list | grep "^colabfold" | awk '{print \$2}')
    END_VERSIONS
    """
}
