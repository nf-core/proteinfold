nextflow.enable.dsl=2

include { collectMultiqcMetrics } from '../main'

process MAKE_PROBE_METRICS {
    input:
    tuple val(meta), val(sample_id)

    output:
    tuple val(meta), path("${sample_id}_plddt.tsv"), emit: plddt
    tuple val(meta), path("${sample_id}_msa.tsv"), path("${sample_id}_coverage.png"), emit: msa
    tuple val(meta), path("${sample_id}_ptm.tsv"), emit: ptm
    tuple val(meta), path("${sample_id}_iptm.tsv"), emit: iptm

    script:
    """
    printf 'Positions\\trank_0\\trank_1\\n1\\t90.0\\t80.0\\n' > ${sample_id}_plddt.tsv
    printf '12\\n' > ${sample_id}_msa.tsv
    touch ${sample_id}_coverage.png
    printf '0\\t0.40\\n1\\t0.30\\n' > ${sample_id}_ptm.tsv
    printf '0\\t0.80\\n1\\t0.70\\n' > ${sample_id}_iptm.tsv
    """
}

workflow COLLECT_MULTIQC_METRICS_PROBE {

    main:
    MAKE_PROBE_METRICS(channel.of([ [ id: 'S1' ], 'S1' ], [ [ id: 'S2' ], 'S2' ]))

    out_metrics = collectMultiqcMetrics(params.probe_mode, [
        [ 'plddt', MAKE_PROBE_METRICS.out.plddt ],
        [ 'msa',   MAKE_PROBE_METRICS.out.msa ],
        [ 'ptm',   MAKE_PROBE_METRICS.out.ptm ],
        [ 'iptm',  MAKE_PROBE_METRICS.out.iptm ],
    ])

    emit:
    metrics = out_metrics
}
