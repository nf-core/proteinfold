/*
 * Extract metrics from AlphaFold2 outputs
 */
process EXTRACT_METRICS_AF2 {
    tag "$meta.id"
    label 'process_single'

    container "${params.alphafold2_mode == 'split_msa_prediction' ? 'nf-core/proteinfold_alphafold2_pred:2.0.0' : 'nf-core/proteinfold_alphafold2_standard:2.0.0'}"

    input:
    tuple val(meta), path(raw), path(features)

    output:
    tuple val(meta), path("${meta.id}_plddt.tsv")          , emit: multiqc
    tuple val(meta), path("${meta.id}_alphafold2_msa.tsv") , emit: msa
    tuple val(meta), path("${meta.id}_*_pae.tsv")          , optional: true, emit: paes
    tuple val(meta), path("${meta.id}_0_pae.tsv")          , optional: true, emit: pae
    tuple val(meta), path("${meta.id}_ptm.tsv")            , optional: true, emit: ptms
    tuple val(meta), path("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    path "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python3 "\$(command -v extract_metrics.py)" --name ${meta.id} \\
        --pkls *.pkl \\
        --structs ranked*.pdb

    mv "${meta.id}_msa.tsv" "${meta.id}_alphafold2_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_alphafold2_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
