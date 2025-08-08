process FASTA2JSON {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(fasta)
    output:
    tuple val(meta), path ("*.json"), emit: json
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    #!/usr/bin/env python3
    import os, sys
    import json
    import copy
    seq_template = {
            "type": "",
            "sequence": "",
            "count": 1
        }
    final_res = {"entities": []}
    seq_type = "protein"
    counter = 0
    fasta_data = ""

    with open("${fasta}", "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if line.startswith(">"):
            if len(fasta_data) > 0:
                new_entry = copy.deepcopy(seq_template)
                new_entry["type"] = seq_type
                new_entry["sequence"] = fasta_data
                final_res["entities"].append(new_entry)
            counter += 1
            fasta_data = ""
        else:
            fasta_data += f"{line}"
    if len(fasta_data) > 0:
        new_entry = copy.deepcopy(seq_template)
        new_entry["type"] = seq_type
        new_entry["sequence"] = fasta_data
        final_res["entities"].append(new_entry)

    with open("${meta.id}.json", "w") as json_file:
        json.dump(final_res, json_file, indent=4, sort_keys=True)

    with open ("versions.yml", "w") as version_file:
        version_file.write("\\"${task.process}\\":\\n    python: {}\\n".format(sys.version.split()[0].strip()))
    """

    stub:
    """
    touch "${meta.id}.json"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
