process RUN_ESMFOLD {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://athbaltzis/esmfold:v0.1' :
        'athbaltzis/esmfold:v0.1' }"

    input:
    tuple val(meta), path(fasta)
    path ('./checkpoint')
    val numRec

    output:
    path ("${fasta.baseName}*.pdb"), emit: pdb
    path ("${fasta.baseName}_plddt_mqc.tsv"), emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def VERSION = '1.0.3' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    esm-fold \
        -i ${fasta} \
        -o \$PWD \
        -m ./checkpoints \
        --num-recycles ${numRec} \
        $args

    awk '{print \$6"\\t"\$11}' "${fasta.baseName}"*.pdb | uniq > "${fasta.baseName}"_plddt_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        esm-fold: $VERSION
    END_VERSIONS
    """

    stub:
    def VERSION = '1.0.3' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch ./"${fasta.baseName}".pdb
    touch ./"${fasta.baseName}"_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        esm-fold: $VERSION
    END_VERSIONS
    """
}
