/*
 * Run RF2NA (RoseTTAFold 2 for Nucleic Acids)
 */
process RUN_ROSETTAFOLD2NA {
    tag "$meta.id"
    label 'process_medium'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_RF2NA module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    container "quay.io/patribota/proteinfold_rosettafold2na:dev"

    input:
    tuple val(meta), path(fasta_files)
    path ('bfd/*')
    path ('UniRef30_2020_06/*')
    path ('pdb100_2021Mar03/*')
    path ('RNA/*')
    path ('*')

    output:
    tuple val(meta), path("${meta.id}_rf2na_output"), emit: output_dir
    tuple val(meta), path("${meta.id}_rf2na.pdb"), emit: pdb
    tuple val(meta), path("${meta.id}_rf2na_output/models/model_00.npz"), emit: npz
    tuple val(meta), path("*_mqc.tsv"), emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def VERSION = 'dev' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    def fasta_args = fasta_files.collect { fasta ->
        def prefix = fasta.name.tokenize(':')[0]
        if (prefix == 'P') return "P:${fasta}"
        else if (prefix == 'R') return "R:${fasta}"
        else if (prefix == 'D') return "D:${fasta}"
        else if (prefix == 'S') return "S:${fasta}"
        else if (prefix == 'PR') return "PR:${fasta}"
        else return fasta
    }.join(' ')

    """
    run_RF2NA.sh ${meta.id}_rf2na_output $fasta_args

    cp ${meta.id}_rf2na_output/models/model_00.pdb ./${meta.id}_rf2na.pdb

    awk '{printf "%s\\t%.0f\\n", \$6, \$11 * 100}' "${meta.id}_rf2na.pdb" | uniq > plddt.tsv
    echo -e Positions"\\t""${meta.id}"_rf2na.pdb > header.tsv
    cat header.tsv plddt.tsv > "${meta.id}"_plddt_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_rf2na_output/models
    touch ${meta.id}_rf2na_output/models/model_00.pdb
    touch ${meta.id}_rf2na_output/models/model_00.npz
    touch ${meta.id}_rf2na.pdb
    touch "${meta.id}"_plddt_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rf2na: $VERSION
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}