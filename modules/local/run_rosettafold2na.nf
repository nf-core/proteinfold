process RUN_ROSETTAFOLD2NA {
    tag "$meta.id"
    label 'gpu_compute'
    label 'process_high'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ROSETTAFOLD2NA module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    container "quay.io/patribota/proteinfold_rosettafold2na:dev"

    input:
    tuple val(meta), path(fasta)
    path ('UniRef30_2020_06/*')
    path ('bfd/*')
    path ('pdb100_2021Mar03/*')
    path ('RF2NA_apr23.tgz')
    path ('Rfam.cm')
    path ('rfam_annotations.tsv')
    path ('id_mapping.tsv')
    path ('rnacentral.fasta')
    path ('nt')

    output:
    tuple val(meta), path("${meta.id}_rosettafold2na.pdb"), emit: pdb
    tuple val(meta), path("${meta.id}_plddt_mqc.tsv"), emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    ln -s /app/RoseTTAFold2NA/* .
    
    # Prepare RNA databases
    mkdir -p RNA
    mv Rfam.cm RNA/
    mv rfam_annotations.tsv RNA/
    mv id_mapping.tsv RNA/
    mv rnacentral.fasta RNA/
    mv nt RNA/
    
    # Extract RF2NA weights
    tar -xzf RF2NA_apr23.tgz

    python -m rf2na.run_inference ${args} \\
        --fasta ${fasta} \\
        --uniref30 UniRef30_2020_06 \\
        --bfd bfd \\
        --pdb100 pdb100_2021Mar03 \\
        --rna_dir RNA \\
        --weights RF2NA_apr23 \\
        --output ${meta.id}_rosettafold2na

    awk '{printf "%s\\t%.0f\\n", \$6, \$11 * 100}' ${meta.id}_rosettafold2na.pdb | uniq > plddt.tsv
    echo -e Positions"\\t"${meta.id}_rosettafold2na.pdb > header.tsv
    cat header.tsv plddt.tsv > ${meta.id}_plddt_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rosettafold2na: \$(python -m rf2na.run_inference --version 2>&1 | sed 's/^.*version //; s/Using.*\$//')
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_rosettafold2na.pdb
    touch ${meta.id}_plddt_mqc.tsv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rosettafold2na: 1.0.0
        python: 3.8.0
    END_VERSIONS
    """
}