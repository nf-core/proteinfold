process RUN_ESMFOLD {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_esmfold:2.0.0"

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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        esm-fold: $VERSION
        python: \$(python3 --version | sed 's/Python //g')
        pytorch: \$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
        openfold: \$(python -m pip show openfold | grep "^Version" | sed 's/.*Version: //' 2>/dev/null || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    def VERSION = '1.0.3' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch "${meta.id}_esmfold.pdb"
    touch "${meta.id}_plddt.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        esm-fold: $VERSION
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        pytorch: \$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
        openfold: \$(python -m pip show openfold 2>/dev/null | grep "^Version" | sed 's/.*Version: //' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
