include { VALIDATE_INPUTS } from '../modules/local/run_dockq_validate_inputs/main'
include { RUN_DOCKQ       } from '../modules/local/run_dockq/main'

workflow DOCKQ {
    take:
    model     // tuple val(meta), path(model_pdb)
    reference    // tuple val(meta), path(reference_pdb)

    main:
    VALIDATE_INPUTS(model, reference)
    RUN_DOCKQ(model, reference)

    emit:
    json     = RUN_DOCKQ.out.json
    txt      = RUN_DOCKQ.out.txt
    versions = RUN_DOCKQ.out.versions
}