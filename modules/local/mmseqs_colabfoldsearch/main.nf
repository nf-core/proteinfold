process MMSEQS_COLABFOLDSEARCH {
    tag "$meta.id"
    label 'process_high_memory'
    label 'process_high'

    container "ghcr.io/tlitfin/wisps-colabfold-search:1.1"

    input:
    tuple val(meta), path(fasta)
    path ('db/*')
    path ('uniref30/*')

    output:
    tuple val(meta), path("**.a3m"), emit: a3m
    tuple val(meta), path("**.json"), emit: json
    tuple val("${task.process}"), val('colabfold_search'), eval("pip list | grep \"^colabfold\" | awk '{print \\\$2}' 2>/dev/null || echo \"unknown\""), emit: versions_colabfold_search, topic: versions
    tuple val("${task.process}"), val('mmseqs'), eval("mmseqs version 2>/dev/null | head -1"), emit: versions_mmseqs, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local MMSEQS_COLABFOLDSEARCH module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''

    """
    for f in uniref30/*; do
        if [ ! -e "db/\$(basename \$f)" ]; then
            ln -sf \$(realpath \$f) db/\$(basename \$f)
        else
            echo "WARNING: skipping uniref30/\$(basename \$f) -- already present from colabfold_db" >&2
        fi
    done

    colabfold_search \\
        $args \\
        --threads $task.cpus ${fasta} \\
        ./db \\
        --af3-json \\
        "results/"
    """

    stub:
    """
    mkdir results
    touch results/${meta.id}.a3m
    touch results/${meta.id}.json
    """
}

process MMSEQS_COLABFOLDSEARCH_BATCH {
    tag "batch_${batch_meta*.id.join('_')}"
    label 'process_high_memory'
    label 'process_high'
    container "ghcr.io/tlitfin/wisps-colabfold-search:1.1"

    input:
    tuple val(batch_meta), path(csvs)
    path ('db/*')
    path ('uniref30/*')

    output:
    tuple val(batch_meta), path("results/*.a3m"), emit: a3m
    tuple val(batch_meta), path("results/*.json"), emit: json
    tuple val("${task.process}"), val('colabfold_search'), eval("pip list | grep \"^colabfold\" | awk '{print \\\$2}' 2>/dev/null || echo \"unknown\""), emit: versions_colabfold_search, topic: versions
    tuple val("${task.process}"), val('mmseqs'), eval("mmseqs version 2>/dev/null | head -1"), emit: versions_mmseqs, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local MMSEQS_COLABFOLDSEARCH_BATCH module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    """
    for f in uniref30/*; do
        [ -e "db/\$(basename \$f)" ] || ln -sf \$(realpath \$f) db/\$(basename \$f)
    done
    first=1
    for f in ${csvs}; do
        if [ \$first -eq 1 ]; then cat "\$f" > input.csv; first=0
        else tail -n +2 "\$f" >> input.csv; fi
    done
    colabfold_search $args --threads $task.cpus input.csv ./db --af3-json results/
    for f in ${csvs}; do
        id=\$(basename "\$f" .csv)
        test -s "results/\${id}.a3m" || { echo "Missing A3M output for \$id" >&2; exit 1; }
        test -s "results/\${id}.json" || { echo "Missing JSON output for \$id" >&2; exit 1; }
    done
    """

    stub:
    """
    mkdir results
    for f in ${csvs}; do id=\$(basename "\$f" .csv); printf '>stub\n' > results/\${id}.a3m; printf '{"stub":true}\n' > results/\${id}.json; done
    """
}
