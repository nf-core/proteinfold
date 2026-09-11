process BOLTZ_YAML_TO_COLABFOLD_FASTA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/de/deb97ccf27bd258b3f42fccf4fbc19e5cefe8582359699e12a808bdedb2cc5a8/data' :
        'community.wave.seqera.io/library/pip_pyyaml:c2bd49f8575c1263' }"

    input:
    tuple val(meta), path(boltz_yaml)

    output:
    tuple val(meta), path("*.pdb"), emit: pdb
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //g'"), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    for mmcif in *.cif
    do
        pdb_out=\$(basename "\$mmcif" .cif)
        mmcif_to_pdb.py \${mmcif} --pdb_out "\${pdb_out}.pdb"
    done
    """

    stub:
    """
    for mmcif in *.cif
    do
        pdb_out=\$(basename "\$mmcif")
        touch \${pdb_out}.pdb
    done
    """
}
