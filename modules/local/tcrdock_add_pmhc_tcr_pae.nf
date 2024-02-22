process TCRDOCK_ADD_PMHC_TCR_PAE {
    tag "$batch_name"
    label 'process_low'

    publishDir path: "$params.outdir/$params.mode/prediction/$batch_name", mode: 'copy', saveAs: { filename -> filename.equals('versions.yml') ? null : filename }

    // // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
    //     'biocontainers/YOUR-TOOL-HERE' }"
    // TODO elias: add the container the right way.
    def VERSION = '1.0.0'
    container "tcrdock:${VERSION}"

    input:
    tuple val(batch_name), path(prediction_output_tsv)

    output:
    tuple val(batch_name), path("user_output_final.tsv"), emit: output
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    
    """
    python /opt/TCRdock/add_pmhc_tcr_pae_to_tsvfile.py \
    --infile $prediction_output_tsv \
    --outfile user_output_final.tsv \
    --clobber \
    $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tcrdock: $VERSION
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    
    """
    touch user_output_final.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tcrdock: $VERSION
    END_VERSIONS
    """
}
