process TCRDOCK_SAMPLESHEET_PARSE {
    tag "$samplesheet"
    label 'process_single'

    publishDir path: "$params.outdir/$params.mode/batches", mode: "copy", saveAs: { filename -> filename.equals('versions.yml') ? null : filename }

    def PANDAS_VERSION = '1.4.3'
    conda "conda-forge::pandas=$PANDAS_VERSION"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:' :
        'quay.io/biocontainers/pandas:' }$PANDAS_VERSION"

    input:
    path samplesheet

    output:
    path '*.tsv'       , emit: tsvs
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/proteinfold/bin/
    def batch_size = params.batch_size ?: 10
    """
    tcrdock_parse_samplesheet.py \\
        $samplesheet \\
        $batch_size

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        pandas: $PANDAS_VERSION
    END_VERSIONS
    """
}
