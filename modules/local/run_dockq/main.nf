process RUN_DOCKQ {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}/dockq", mode: 'copy'
    container "proteinfold/proteinfold_dockq:2.1.3"

    input:
    tuple val(meta), path(model_pdb)   
    tuple val(meta), path(native_pdb)  

    output:
    tuple val(meta), path("${meta.id}_dockq.json")   , emit: json
    tuple val(meta), path("${meta.id}_dockq.txt")    , emit: txt
    path "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("RUN_DOCKQ module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    """
    DockQ \\
        ${model_pdb} \\
        ${native_pdb} \\
        --json ${meta.id}_dockq.json \\
        ${args} \\
        | tee ${meta.id}_dockq.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dockq: \$(DockQ --version 2>&1 | head -1 | awk '{print \$NF}' || echo "2.1.3")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_dockq.json"
    touch "${meta.id}_dockq.txt"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dockq: 2.1.3
    END_VERSIONS
    """
}