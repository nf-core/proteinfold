process SAMPLESHEET_BOLTZ_MSA {
    tag "$meta.id"
    label "process_medium"

    container "/srv/scratch/sbf/containers/samplesheet-utils-1.3.sif"

    input:
    tuple val(meta), path(fasta), path(msa)

    output:
    tuple val(meta), path("samplesheet.yaml"), emit: formatted_yaml

    script:
    """
    create-samplesheet \
        --directory ./ \
        --msa-dir ./ \
        --output-file samplesheet.yaml \
        --yaml
    """
}
