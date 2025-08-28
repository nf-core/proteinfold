process RUN_ESMFOLD {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_esmfold:dev"

    input:
    tuple val(meta), path(fasta)
    path ('./checkpoints/')
    val numRec

    output:
    tuple val(meta), path ("${meta.id}_esmfold.pdb")  , emit: top_ranked_pdb
    tuple val(meta), path ("*.pdb")                   , emit: pdb
    tuple val(meta), path ("${meta.id}_plddt.tsv")    , emit: multiqc
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ESMFOLD module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    def VERSION = '1.0.3' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    // KR - note: removed the *.pdb -> tmp.pdb, tmp.pdb  -> esmfold.pdb. Why not just take directly?
    // Only one .pdb per ESMFold run
    """
    esm-fold \
        -i ${fasta} \
        -o \$PWD \
        -m \$PWD \
        --num-recycles ${numRec} \
        $args

    mv  *.pdb ${meta.id}_esmfold.pdb

    extract_metrics.py --name ${meta.id} \\
        --structs ${meta.id}_esmfold.pdb

    # No MSA information in ESMFold
    # PAE from ESMFold is an absolute pain to retrieve, skipping.
    # https://github.com/facebookresearch/esm/issues/582
    # Since neither MSA or PAE exist, dummy files are generated
    if [ ! -f "${meta.id}_msa.tsv" ]; then
        echo "0" > "${meta.id}_msa.tsv"
    fi
    if [ ! -f "${meta.id}_0_pae.tsv" ]; then
        echo "0" > "${meta.id}_0_pae.tsv"
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        esm-fold: $VERSION
    END_VERSIONS
    """

    stub:
    def VERSION = '1.0.3' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch "${meta.id}_esmfold.pdb"
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_msa.tsv"
    touch "${meta.id}_0_pae.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        esm-fold: $VERSION
    END_VERSIONS
    """
}
