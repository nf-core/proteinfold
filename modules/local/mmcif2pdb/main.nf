process MMCIF2PDB {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/eb/eb3700531c7ec639f59f084ab64c05e881d654dcf829db163539f2f0b095e09d/data' :
        'community.wave.seqera.io/library/biopython:1.84--3318633dad0031e7' }"

    input:
    tuple val(meta), path("*")

    output:
    tuple val(meta), path("*.pdb"), emit: pdb
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    for mmcif in *.cif
    do
        pdb_out=\$(basename "\$mmcif")
        mmcif_to_pdb.py \${mmcif} --pdb_out "\${pdb_out}.pdb"
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    for mmcif in *.cif
    do
        pdb_out=\$(basename "\$mmcif")
        touch \${pdb_out}.pdb
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
