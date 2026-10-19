process ASSEMBLE_MODELCIF {
    tag "$meta.id-$meta.model"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'ghcr.io/keiran-rowell-unsw/proteinfold-modelcif:1.7'

    input:
    tuple val(meta), path(structs), path(msa), path(plddt), path(pae), path(ptm), path(iptm), path(versions_yml)

    output:
    tuple val(meta), path("*.mmcif"), emit: modelcif
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    populate_modelcif.py --structs ${structs} --msa ${msa} --plddt ${plddt} --pae ${pae} --ptm ${ptm} --iptm ${iptm} --name ${meta.id} --prog ${meta.model} --versions_yml ${versions_yml} --msa_tool ${meta.msa_tool ?: 'None'} $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modelcif: \$(python3 -c "import modelcif; print(modelcif.__version__)")
    END_VERSIONS
    """
}
