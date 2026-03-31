process COLABFOLD_BATCH {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_colabfold:2.0.0"

    input:
    tuple val(meta), path(fasta)
    val   colabfold_model_preset
    path  ('params/*')
    path  ('colabfold_db/*')
    path  ('uniref30/*')
    val   numRec

    output:
    path ("raw/**")                                         , emit: raw
    tuple val(meta), path ("${meta.id}_colabfold.pdb")      , emit: top_ranked_pdb
    tuple val(meta), path ("raw/*relaxed_rank_*.pdb")       , emit: pdb
    tuple val(meta), path ("${meta.id}_colabfold_msa.tsv")  , emit: msa
    tuple val(meta), path ("${meta.id}_plddt.tsv")          , emit: plddt
    tuple val(meta), path ("${meta.id}_*_pae.tsv")          , optional: true, emit: paes
    tuple val(meta), path ("${meta.id}_0_pae.tsv")          , optional: true, emit: pae
    tuple val(meta), path ("${meta.id}_ptm.tsv")            , optional: true, emit: ptms
    tuple val(meta), path ("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local COLABFOLD_BATCH module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''

    """
    if compgen -G "params/alphafold_params_*" >/dev/null; then
        ln -s \$(realpath params/alphafold_params_*/*) params/
    fi

    touch params/download_finished.txt
    touch params/download_complexes_multimer_v3_finished.txt
    touch params/download_complexes_multimer_v2_finished.txt
    touch params/download_complexes_multimer_v1_finished.txt

    colabfold_batch \\
        $args \\
        --num-recycle ${numRec} \\
        --data \$PWD \\
        --model-type ${colabfold_model_preset} \\
        ${fasta} \\
        raw/

    if [ ! -e `find raw/*_relaxed_rank_001_*.pdb` ]; then
        prefix=relaxed
        cp raw/*_relaxed_rank_001*.pdb ${meta.id}_colabfold.pdb
    else
        prefix=unrelaxed
        cp raw/*_unrelaxed_rank_001*.pdb ${meta.id}_colabfold.pdb
    fi

    extract_metrics.py --name ${meta.id} \\
        --colabfold_metrics_fns raw/*scores_rank*.json \\
        --structs raw/*_\${prefix}_rank*.pdb \\
        --paired_a3m raw/${meta.id}.a3m

    cp raw/*_coverage.png ${meta.id}_seq_coverage.png
    mv "${meta.id}_msa.tsv" "${meta.id}_colabfold_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        alphafold_colabfold: \$(pip list | grep "^alphafold-colabfold" | awk '{print \$2}' 2>/dev/null || echo "unknown")
        colabfold_batch: \$(pip list | grep "^colabfold" | awk '{print \$2}' 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    mkdir raw
    touch ./"${meta.id}"_colabfold.pdb
    touch ./raw/${meta.id}_relaxed_rank_001_model_1_seed_000.pdb
    touch ./raw/${meta.id}_relaxed_rank_002_model_2_seed_000.pdb
    touch ./raw/${meta.id}_relaxed_rank_003_model_3_seed_000.pdb
    touch ./${meta.id}_seq_coverage.png
    touch ./raw/${meta.id}_scores_rank.json
    touch ./${meta.id}_0_pae.tsv
    touch ./${meta.id}_ptm.tsv
    touch ./${meta.id}_plddt.tsv
    touch ./${meta.id}_colabfold_msa.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        alphafold_colabfold: \$(pip list | grep "^alphafold-colabfold" | awk '{print \$2}' 2>/dev/null || echo "unknown")
        colabfold_batch: \$(pip list | grep "^colabfold" | awk '{print \$2}' 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
