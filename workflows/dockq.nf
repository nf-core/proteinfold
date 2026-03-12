include { VALIDATE_INPUTS } from '../modules/local/run_dockq_validate_inputs/main'
include { RUN_DOCKQ       } from '../modules/local/run_dockq/main'

workflow DOCKQ {
    take:
    model     // tuple val(meta), path(model_pdb)
    native    // tuple val(meta), path(native_pdb)

    main:
    VALIDATE_INPUTS(model, native)
    RUN_DOCKQ(model, native)

    emit:
    json     = RUN_DOCKQ.out.json
    txt      = RUN_DOCKQ.out.txt
    versions = RUN_DOCKQ.out.versions
}