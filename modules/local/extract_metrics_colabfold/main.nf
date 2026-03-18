/*
 * Extract metrics from ColabFold outputs
 */
process EXTRACT_METRICS_COLABFOLD {
    tag "$meta.id"
    label 'process_single'

    container "nf-core/proteinfold_colabfold:2.0.0"

    input:
    tuple val(meta), path(raw)

    output:
    tuple val(meta), path("${meta.id}_colabfold_msa.tsv")  , emit: msa
    tuple val(meta), path("${meta.id}_plddt.tsv")          , emit: multiqc
    tuple val(meta), path("${meta.id}_*_pae.tsv")          , optional: true, emit: paes
    tuple val(meta), path("${meta.id}_0_pae.tsv")          , optional: true, emit: pae
    tuple val(meta), path("${meta.id}_ptm.tsv")            , optional: true, emit: ptms
    tuple val(meta), path("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    path "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    prefix=unrelaxed
    if ls *_relaxed_rank_001_*.pdb >/dev/null 2>&1; then
        prefix=relaxed
    fi

    extract_metrics.py --name ${meta.id} \\
        --colabfold_metrics_fns *scores_rank*.json \\
        --structs *_\${prefix}_rank*.pdb \\
        --paired_a3m ${meta.id}.a3m

    mv "${meta.id}_msa.tsv" "${meta.id}_colabfold_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        alphafold_colabfold: \$(pip list | grep "^alphafold-colabfold" | awk '{print \$2}' 2>/dev/null || echo "unknown")
        colabfold_batch: \$(pip list | grep "^colabfold" | awk '{print \$2}' 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
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
