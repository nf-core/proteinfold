process SPLIT_MSA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/de/deb97ccf27bd258b3f42fccf4fbc19e5cefe8582359699e12a808bdedb2cc5a8/data' :
        'community.wave.seqera.io/library/pip_pyyaml:c2bd49f8575c1263' }"

    input:
    tuple val(meta), path(msa), path(template_yaml, stageAs: 'original.yaml')
    output:
    tuple val(meta), path ("output_msa/*.csv"), emit: msa_csv
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //g'"), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    msa_manager.py ${msa} -o output_msa --meta_id ${meta.id}
    """

    stub:
    """
    mkdir output_msa
    touch "output_msa/A.csv"
    touch "output_msa/B.csv"
    """
}
