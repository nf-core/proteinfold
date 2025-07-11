/*
 * Run RF2NA (RoseTTAFold 2 for Nucleic Acids)
 */
process RUN_ROSETTAFOLD2NA {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_rosettafold2na:dev"

    input:
    tuple val(meta), path(protein_fasta), path(interaction_fasta)
    path ('bfd/*')
    path ('UniRef30_2020_06/*')
    path ('pdb100_2021Mar03/*')
    path ('RNA/*')
    path ('network/weights/*')

    output:
    tuple val(meta), path("${meta.id}_rf2na.pdb"), emit: pdb
    tuple val(meta), path("${meta.id}_plddt_mqc.tsv"), emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_RF2NA module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    def args = task.ext.args ?: ''
    def VERSION = 'dev' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    # Otherwise will through error when running .command.{sh,run} for debugging
    if [ ! -e "\$PWD/run_RF2NA.sh" ]; then
        ln -s /app/RoseTTAFold2NA/run_RF2NA.sh ./
        mkdir ./input_prep
        ln -s /app/RoseTTAFold2NA/input_prep/* ./input_prep
        ln -s /app/RoseTTAFold2NA/network/* ./network
    fi

    ./run_RF2NA.sh ${meta.id}_rf2na_output $protein_fasta ${meta.interaction_type}:${interaction_fasta}

    cp ${meta.id}_rf2na_output/models/model_00.pdb ./${meta.id}_rf2na.pdb

    awk '{printf "%s\\t%.0f\\n", \$6, \$11 * 100}' "${meta.id}_rf2na.pdb" | uniq > plddt.tsv
    echo -e Positions"\\t""${meta.id}"_rf2na.pdb > header.tsv
    cat header.tsv plddt.tsv > "${meta.id}_plddt_mqc.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_rf2na.pdb"
    touch "${meta.id}_plddt_mqc.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
