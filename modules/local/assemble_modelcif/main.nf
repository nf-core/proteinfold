process ASSEMBLE_MODELCIF {
    tag "$meta.id-$meta.model"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'ghcr.io/keiran-rowell-unsw/proteinfold-modelcif:1.7'

    input:
    tuple val(meta), path(struct), path(plddt)

    output:
    tuple val(meta), path("*.mmcif"), emit: modelcif
    path "versions.yml", emit: versions

    script:
    """
    populate_modelcif.py --structs ${struct} --plddt ${plddt} --name ${meta.id} --prog ${meta.model}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modelcif: \$(python3 -c "import modelcif; print(modelcif.__version__)")
    END_VERSIONS
    """
}
