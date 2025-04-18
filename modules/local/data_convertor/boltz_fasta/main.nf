process BOLTZ_FASTA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(fasta), path(msa)
    output:
    tuple val(meta), path ("output_fasta/*.fasta"), path(msa), emit: formatted_fasta
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    #!/usr/bin/env python3
    import os, sys
    import string
    #def safe_filename(file: str) -> str:
    #    return "".join([c if c.isalnum() or c in ["_", ".", "-"] else "_" for c in file]) + ".a3m"

    all_combinations = list(string.ascii_uppercase) + list(string.ascii_lowercase) + [str(x) for x in range(0, 10)]
    msa_files = ["${msa.join('", "')}"]
    seq_type = "protein"
    os.makedirs("output_fasta", exist_ok=True)
    counter = 0
    with open("${fasta}", "r") as f:
        lines = f.readlines()
    msa = ""
    fasta_data = "key,sequence\\n"
    for line in lines:
        line = line.strip()
        if line.startswith(">"):
            if len(msa_files) > 0:
                msa = f"|{os.path.basename(msa_files[counter])}"
                if msa[1:] not in msa_files:
                    print(f"Can not find msa file {os.path.basename(msa_files[counter])}")
                    exit(1)
            
            fasta_data += f">{all_combinations[counter]}|{seq_type}{msa}\\n"
            counter += 1
        else:
            fasta_data += f"{line}\\n"
    
    if len(fasta_data) > 0:
        with open(f"output_fasta/${meta.id}.fasta", "w") as outfile:
            outfile.write(fasta_data)

    with open ("versions.yml", "w") as version_file:
	    version_file.write("\\"${task.process}\\":\\n    python: {}\\n".format(sys.version.split()[0].strip()))
    """

    stub:
    """
    mkdir output_fasta
    touch "output_fasta/${meta.id}.fasta"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
