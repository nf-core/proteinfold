/*
 * Run RF2NA
 */
process RUN_ROSETTAFOLD2NA {
    tag "$meta.id"
    label 'process_medium'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ROSETTAFOLD2NA module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    // Use the RF2NA container image
    container "quay.io/patribota/proteinfold_rosettafold2na:dev"

    input:
        // Tuple with metadata and the FASTA/config file
        tuple val(meta), path(fasta)
        // Required database directories:
        path ('bfd/*')
        path ('UniRef30_2020_06/*')
        path ('pdb100_2021Mar03/*')
        // Added for RNA databases:
        path ('RNA/*')
        // Catch-all pattern: matches any other files not already matched.
        path ('*')

    output:
        // Emit the predicted PDB file with a new name based on meta.id
        tuple val(meta), path("${meta.id}_rf2na.pdb"), emit: pdb
        // Emit a MultiQC TSV file (e.g. for per-residue LDDT scores)
        tuple val(meta), path("*_plddt_mqc.tsv"), emit: multiqc
        // Versions file for reproducibility
        path "versions.yml", emit: versions

    when:
        task.ext.when == null || task.ext.when

    script:
        def args = task.ext.args ?: ''
        """
        # Create symbolic links for the RF2NA installation files.
        ln -s /app/RoseTTAFold2NA/* .

        # Execute the RF2NA run script.
        # The first argument is the output folder (using meta.id),
        # followed by the FASTA (or config name) and any additional arguments.
        ./run_RF2NA.sh ${meta.id} ${fasta} ${args}

        # Copy the generated PDB file (assumed to be named based on the input FASTA's basename)
        cp "${fasta.baseName}.pdb" ./"${meta.id}_rf2na.pdb"

        # Generate a MultiQC-style TSV file by extracting per-residue LDDT values from the PDB.
        awk '{printf "%s\\t%.0f\\n", \$6, \$11 * 100}' "${meta.id}_rf2na.pdb" | uniq > plddt.tsv
        echo -e "Positions\\t${meta.id}_rf2na.pdb" > header.tsv
        cat header.tsv plddt.tsv > "${meta.id}_plddt_mqc.tsv"

        # Write a versions file capturing the Python version.
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python3 --version | sed 's/Python //g')
        END_VERSIONS
        """

    stub:
        """
        # Dummy outputs for testing purposes.
        mkdir -p ${meta.id}/models
        touch ${meta.id}/models/model_00.pdb
        touch ${meta.id}_rf2na.pdb
        touch ${meta.id}_plddt_mqc.tsv
        mkdir ./outputs
        mkdir ./"${meta.id}"

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python3 --version | sed 's/Python //g')
        END_VERSIONS
        """
}
