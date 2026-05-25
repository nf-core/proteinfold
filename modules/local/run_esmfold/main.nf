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
    tuple val(meta), path ("${meta.id}_plddt_mqc.tsv"), emit: multiqc
    tuple val("${task.process}"), val('esm-fold'), val('1.0.3'), emit: versions_esmfold, topic: versions
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('pytorch'), eval("python3 -c \"import torch; print(torch.__version__)\" 2>/dev/null || echo \"unknown\""), emit: versions_pytorch, topic: versions
    tuple val("${task.process}"), val('openfold'), eval("python -m pip show openfold | grep \"^Version\" | sed 's/.*Version: //' 2>/dev/null || echo \"unknown\""), emit: versions_openfold, topic: versions
    tuple val("${task.process}"), val('numpy'), eval("python3 -c \"import numpy; print(numpy.__version__)\" 2>/dev/null || echo \"unknown\""), emit: versions_numpy, topic: versions
    tuple val("${task.process}"), val('biopython'), eval("python3 -c \"import Bio; print(Bio.__version__)\" 2>/dev/null || echo \"unknown\""), emit: versions_biopython, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ESMFOLD module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
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
    """

    stub:
    """
    touch "${meta.id}_esmfold.pdb"
    touch "${meta.id}_plddt_mqc.tsv"
    """
}
