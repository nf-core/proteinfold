/*
 * Extract metrics from HelixFold3 outputs
 */
process EXTRACT_METRICS_HELIXFOLD3 {
    tag "$meta.id"
    label 'process_single'

    container "nf-core/proteinfold_helixfold3:2.0.0"

    input:
    tuple val(meta), path(raw)

    output:
    tuple val(meta), path("${meta.id}_plddt.tsv")          , emit: multiqc
    tuple val(meta), path("${meta.id}_helixfold3_msa.tsv") , emit: msa
    tuple val(meta), path("${meta.id}_1_pae.tsv")          , emit: pae
    tuple val(meta), path("${meta.id}_*_pae.tsv")          , emit: paes
    tuple val(meta), path("${meta.id}_ptm.tsv")            , emit: ptms
    tuple val(meta), path("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    path ("versions.yml")                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mamba run --name helixfold extract_metrics.py --name ${meta.id} \\
        --structs ${raw}/${raw.baseName}-rank*/predicted_structure.pdb \\
        --pkls "${raw}/final_features.pkl" \\
        --jsons ${raw}/${raw.baseName}-rank*/all_results.json

    mv "${meta.id}_msa.tsv" "${meta.id}_helixfold3_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_helixfold3_msa.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_1_pae.tsv"
    touch "${meta.id}_2_pae.tsv"
    touch "${meta.id}_3_pae.tsv"
    touch "${meta.id}_4_pae.tsv"
    touch "${meta.id}_5_pae.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
    END_VERSIONS
    """
}
