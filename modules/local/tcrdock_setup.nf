process TCRDOCK_SETUP {
    tag "$batch_name"
    label 'process_low'

    publishDir path: "$params.outdir/$params.mode/setup/$batch_name", mode: 'copy', saveAs: { filename -> filename.equals('versions.yml') ? null : filename }

    // // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
    //     'biocontainers/YOUR-TOOL-HERE' }"
    // TODO elias: add the container the right way.
    def VERSION = '1.0.0'
    container "tcrdock:${VERSION}"

    input:
    tuple val(batch_name), path(samplesheet)

    output:
    tuple val(batch_name), path("*.tsv"), path("*.pdb"), emit: output
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    
    """
    python /opt/TCRdock/setup_for_alphafold.py \
        --targets_tsvfile $samplesheet \
        --output_dir . \
        --maintain_relative_paths \
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tcrdock: $VERSION
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    """
    touch targets.tsv
    touch tcr_db.tsv
    touch XXXX_0_alignments.tsv
    touch XXXX_0_0.pdb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tcrdock: $VERSION
    END_VERSIONS
    """
}
