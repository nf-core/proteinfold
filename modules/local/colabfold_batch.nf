process COLABFOLD_BATCH {
    tag "$meta.id"
    label 'process_medium'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local COLABFOLD_BATCH module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    container "nf-core/proteinfold_colabfold:dev"

    input:
    tuple val(meta), path(fasta)
    val   colabfold_model_preset
    path  ('params/*')
    path  ('colabfold_db/*')
    path  ('uniref30/*')
    val   numRec

    output:
    tuple val(meta), path ("*_relaxed_rank_*.pdb"), emit: pdb
    tuple val(meta), path ("*_coverage.png")      , emit: msa
    tuple val(meta), path ("*_mqc.png")           , emit: multiqc
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def VERSION = '1.5.2' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    ln -r -s params/alphafold_params_*/* params/
    colabfold_batch \\
        $args \\
        --num-recycle ${numRec} \\
        --data \$PWD \\
        --model-type ${colabfold_model_preset} \\
        ${fasta} \\
        \$PWD
    for i in `find *_relaxed_rank_001*.pdb`; do cp \$i `echo \$i | sed "s|_relaxed_rank_|\t|g" | cut -f1`"_colabfold.pdb"; done
    for i in `find *.png -maxdepth 0`; do cp \$i \${i%'.png'}_mqc.png; done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold_batch: $VERSION
    END_VERSIONS
    """

    stub:
    def VERSION = '1.5.2' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch ./"${fasta.baseName}"_colabfold.pdb
    touch ./"${fasta.baseName}"_mqc.png
    touch ./${fasta.baseName}_relaxed_rank_01.pdb
    touch ./${fasta.baseName}_relaxed_rank_02.pdb
    touch ./${fasta.baseName}_relaxed_rank_03.pdb
    touch ./${fasta.baseName}_coverage.png
    touch ./${fasta.baseName}_scores_rank.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        colabfold_batch: $VERSION
    END_VERSIONS
    """
}
