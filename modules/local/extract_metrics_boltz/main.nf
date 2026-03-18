/*
 * Extract metrics from Boltz outputs
 */
process EXTRACT_METRICS_BOLTZ {
    tag "$meta.id"
    label 'process_single'

    container "nf-core/proteinfold_boltz:2.0.0"

    input:
    tuple val(meta), path(raw)

    output:
    tuple val(meta), path("${meta.id}_plddt.tsv")          , emit: multiqc
    tuple val(meta), path("${meta.id}_boltz_msa.tsv")      , emit: boltz_msa
    tuple val(meta), path("${meta.id}_*_pae.tsv")          , emit: paes
    tuple val(meta), path("${meta.id}_0_pae.tsv")          , emit: pae
    tuple val(meta), path("${meta.id}_ptm.tsv")            , emit: ptms
    tuple val(meta), path("${meta.id}_iptm.tsv")           , optional: true, emit: iptms
    tuple val(meta), path("${meta.id}_chainwise_ptm.tsv")  , emit: chainwise_ptm
    tuple val(meta), path("${meta.id}_chainwise_iptm.tsv") , optional: true, emit: chainwise_iptm
    path "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    if [ -f boltz_results_*/msa/${meta.id}_0.csv ]; then
        cp boltz_results_*/msa/${meta.id}_*.csv ./
    fi

    extract_metrics.py --name ${meta.id} \
        --structs boltz_results_*/predictions/${meta.id}/*.pdb \
        --jsons boltz_results_*/predictions/${meta.id}/confidence_*_model_*.json \
        --npzs boltz_results_*/predictions/${meta.id}/pae_*_model_*.npz \
        --csvs ${meta.id}_*.csv

    mv "${meta.id}_msa.tsv" "${meta.id}_boltz_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_boltz_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_chainwise_ptm.tsv"
    touch "${meta.id}_chainwise_iptm.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
