process GENERATE_REPORT {
    tag   "$meta.id-$meta.model"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/24/241f0746484727a3633f544c3747bfb77932e1c8c252e769640bd163232d9112/data' :
        'community.wave.seqera.io/library/biopython_matplotlib_pip_plotly:35975fa0fc54b2d3' }"

    input:
    tuple val(meta), path(pdb), path(msa), path(pae)
    path(template)

    output:
    tuple val(meta), path ("*report.html")     , emit: report
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    generate_report.py \\
        --report_type standard \\
        --prog ${meta.model} \\
        --msa ${msa} \\
        --pae ${pae} \\
        --structs ${pdb.join(' ')} \\
        --html_template ${template} \\
        --output_dir ./ \\
        --name ${meta.id} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        generate_report.py: \$(python3 --version)
    END_VERSIONS
    """

    stub:
    """
    touch test_alphafold2_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        generate_report.py: \$(python3 --version)
    END_VERSIONS
    """
}
