process DOCKQ {
    tag "${inputpdb.baseName}_vs_${reference.baseName}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "community.wave.seqera.io/library/dockq:2.1.3--12e64dc3fc7d0a10"

    input:
    tuple val(meta), path (inputpdb) , path(reference)

    output:
    path "*.txt", emit: txt

    when:
    task.ext.when == null || task.ext.when

    script:
   
    """
    DockQ \\
        ${inputpdb} ${reference} > Dockq_${inputpdb.baseName}_${reference.baseName}.txt
    """
}
