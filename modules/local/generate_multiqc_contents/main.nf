process GENERATE_MULTIQC_CONTENTS {
    tag   "$meta.model"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/de/deb97ccf27bd258b3f42fccf4fbc19e5cefe8582359699e12a808bdedb2cc5a8/data' :
        'community.wave.seqera.io/library/pip_pyyaml:c2bd49f8575c1263' }"

    input:
    tuple val(meta), path(metric_files)
    path(generator_script)

    output:
    tuple val(meta), path("*_mqc.json"), emit: mqc_json
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('generate_multiqc_contents.py'), eval("python3 --version | sed 's/Python //g'"), emit: versions_generator, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    python3 ${generator_script} \\
        --model ${meta.model} \\
        --output-dir ./ \\
        ${metric_files.join(' ')} \\
        $args
    """

    stub:
    """
    touch proteinfold_${meta.model}_generalstats_mqc.json proteinfold_${meta.model}_plddt_lineplot_mqc.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        generate_multiqc_contents.py: \$(python3 --version)
    END_VERSIONS
    """
}
