process MULTIQC {
    tag "${meta.id}"
    label 'process_single'
    tag "$meta.model"
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/28/2805b9d72bdb00e4f75a63b4ac4bd1e70fd514767e99e4ece3dfff93599e5a67/data'
:         'community.wave.seqera.io/library/multiqc_pandas_pip_setuptools_wheel:beddd1a36f0c89e4' }"

    input:
    tuple val(meta), path(multiqc_files, stageAs: "?/*"), path(multiqc_config, stageAs: "?/*"), path(multiqc_logo), path(replace_names), path(sample_names)

    output:
    tuple val(meta), path("*.html"), emit: report
    tuple val(meta), path("*_data"), emit: data
    tuple val(meta), path("*_plots"), emit: plots, optional: true
    // MultiQC should not push its versions to the `versions` topic. Its input depends on the versions topic to be resolved thus outputting to the topic will let the pipeline hang forever
    tuple val("${task.process}"), val('multiqc'), eval('multiqc --version | sed "s/.* //g"'), emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ? "--filename ${task.ext.prefix}.html" : ''
    def config = multiqc_config ? multiqc_config instanceof List ? "--config ${multiqc_config.join(' --config ')}" : "--config ${multiqc_config}" : ""
    def logo = multiqc_logo ? "--cl-config 'custom_logo: \"${multiqc_logo}\"'" : ''
    def replace = replace_names ? "--replace-names ${replace_names}" : ''
    def samples = sample_names ? "--sample-names ${sample_names}" : ''
    """
    # hermetic install of the pipeline-local plugin; deps come from the conda env (no PyPI at runtime)
    pip install --no-deps --no-build-isolation --target "\$PWD/.multiqc_plugins" ${workflow.projectDir}
    PYTHONPATH="\$PWD/.multiqc_plugins" multiqc \\
        --force \\
        ${args} \\
        ${config} \\
        ${prefix} \\
        ${logo} \\
        ${replace} \\
        ${samples} \\
        .
    """

    stub:
    """
    mkdir multiqc_data
    touch multiqc_data/.stub
    mkdir multiqc_plots
    touch multiqc_plots/.stub
    touch multiqc_report.html
    """
}
