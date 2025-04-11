process BOLTZ_FASTA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), val(ids), path(fasta)
    output:
    path ("output_fasta/*.fasta"), emit: fasta
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    #!/usr/bin/env python3
    import os, sys
    import string
    
    all_combinations = list(string.ascii_uppercase) + list(string.ascii_lowercase) + [str(x) for x in range(0, 10)]
    fasta_files = ["${fasta.join('", "')}"]
    ids = ["${ids.join('", "')}"]
    seq_type = "protein"
    os.makedirs("output_fasta", exist_ok=True)
    for seq_itr in range(len(fasta_files)):
        counter = 0
        fasta_data = ""
        fasta = fasta_files[seq_itr]
        with open(fasta, "r") as f:
            lines = f.readlines()

        for line in lines:
            if line.startswith(">"):
                fasta_data += f">{all_combinations[counter]}|{seq_type}\\n"
                counter += 1
            else:
                fasta_data += f"{line}\\n"
        
        if len(fasta_data) > 0:
            with open(f"output_fasta/{ids[seq_itr]}.fasta", "w") as outfile:
                outfile.write(fasta_data)
    
    
    with open ("versions.yml", "w") as version_file:
	    version_file.write("\\"${task.process}\\":\\n    python: {}\\n".format(sys.version.split()[0].strip()))
    """

    stub:
    """
    mkdir output_fasta
    touch "output_fasta/${ids[0]}.fasta"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
