process ASSEMBLE_MODELCIF {
    tag "$meta.id-$meta.model"
    label 'process_single'

    conda "${moduleDir}/environment.yml"

    // Unpack the tuple assuming every value used is at the path. Pass along a DUMMY_FILE so that the path is always occupied.
    // The populate_modelcif.py can explicitly trigger if the arg.metric is a DUMMY_FILE, and if so, appropriately account for the non-existence of that in the model metadata
    // This is also means no hand-crafted exceptions for particular programs that doesn't make use of some input (MSA - EMSFold), they all obey the same take: pipleline logic
    // TODO: Unsure at this stage best way forward with chain-wise paths. At least modelCIF has the asymmetric unit entity, so we *could* DUMMY_FILE, but I do like the philosophy of don't check things that *can't* exist
    input:
    tuple val(meta), path(structs), path(msa), path(plddt), path(pae), path(ptm), path(iptm), path(versions_yml)
    // TODO: in populate_modelcif the qa_metric can handle PLDDT vs PLDDT01 vs PLDDTAllAtom. No more averging weirdness inside EXTRACT_METRICS
    // TODO: A space will be made for path(ipsae) once 1) it's captured 2) an ipsae custom class extends the modelCIF construction
    // TODO: structs - a proper rank mapping util - ever the concern
    // TODO: meta.seed? (#588)
    // TODONT: database version injection. This can come out of versions.yml, but leave that to a cleaner database handling implementation.

    output:
    tuple val(meta), path("*.{mmcif,bcif}"), emit: modelcif
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    // This will take a maximalist approach to populating the modelCIF
    // Every single structure from a sequence prediction method will be captured in .ModelGroup
    // Every common metric will be captured as a modelCIF qa_metric
    // The advantage is all software metadata and protocol steps are shared between all structures in the .ModelGroup
    // TODO: add --binary flag to output as binaryCIF or not 
    script:
    def args = task.ext.args ?: ''
    """
    populate_modelcif.py \\
        --structs ${structs} \\
        --msa ${msa} \\
        --plddt ${plddt} \\
        --pae ${pae} \\
        --ptm ${ptm} \\
        --iptm ${iptm} \\
        --name ${meta.id} \\
        --prog ${meta.model} \\
        --versions_yml ${versions_yml} \\
        --msa_tool ${meta.msa_tool ?: 'None'} \
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        modelcif: \$(python3 -c "import modelcif; print(modelcif.__version__)" 2>/dev/null || echo "unknown")
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)")
    END_VERSIONS
    """

}
