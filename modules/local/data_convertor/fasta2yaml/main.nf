process FASTA2YAML {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path ("*.yaml"), emit: yaml
    tuple val(meta), path ("out_fasta/*.fasta"), emit: fasta
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    #!/usr/bin/env python3
    import os, sys
    import string
    yaml_template = "defaults:\\n - base\\njob_name: \\"${meta.id}\\"\\nprotein_inputs:\\n"
    seq_type = "protein"
    counter = 0
    fasta_data = ""
    os.makedirs("out_fasta", exist_ok=True)
    all_combinations = list(string.ascii_uppercase) + list(string.ascii_lowercase) + [str(x) for x in range(0, 10)]
    with open("${fasta}", "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if line.startswith(">"):
            if len(fasta_data) > 0:
                with open(f"out_fasta/{all_combinations[counter]}.fasta", "w") as fasta_file:
                    fasta_file.write(fasta_data + "\\n")
                yaml_template += f" {all_combinations[counter]}:\\n  fasta_file: {all_combinations[counter]}.fasta\\n"
                counter += 1
            fasta_data = f"{line}\\n"
        else:
            fasta_data += f"{line}"
    if len(fasta_data) > 0:
        with open(f"out_fasta/{all_combinations[counter]}.fasta", "w") as fasta_file:
            fasta_file.write(fasta_data + "\\n")
        yaml_template += f" {all_combinations[counter]}:\\n  fasta_file: {all_combinations[counter]}.fasta\\n"

    with open("${meta.id}.yaml", "w") as yaml_file:
        yaml_file.write(yaml_template)

    with open ("versions.yml", "w") as version_file:
        version_file.write("\\"${task.process}\\":\\n    python: {}\\n".format(sys.version.split()[0].strip()))
    """

    stub:
    """
    touch "${meta.id}.yaml"
    mkdir out_fasta
    touch "out_fasta/A.fasta"
    touch "out_fasta/B.fasta"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
