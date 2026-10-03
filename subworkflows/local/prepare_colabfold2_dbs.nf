// Validate the staged ColabFold2 weights root and runtime assets.
workflow PREPARE_COLABFOLD2_DBS {
    take:
    colabfold2_params_path // directory containing params/af3
    colabfold2_model       // selected upstream model
    colabfold2_precision   // fp32 or int8

    main:
    def companions = [
        'esmfold2_lm300m': 'esmc_300m',
        'esmfold2_lm600m': 'esmc_600m'
    ]
    def suffix = colabfold2_precision == 'int8' ? '-int8' : ''
    def af3_dir = "${colabfold2_params_path}/params/af3"
    def model_dir = "${af3_dir}/${colabfold2_model}${suffix}"
    def companion = companions[colabfold2_model]

    file(colabfold2_params_path, type: 'dir', checkIfExists: true)
    if (!workflow.stubRun) {
        file(model_dir, type: 'dir', checkIfExists: true)
        file("${model_dir}/download_${colabfold2_model}_${colabfold2_precision}_finished.txt", checkIfExists: true)
        if (companion) {
            file("${model_dir}/${colabfold2_model}.lm.npz", checkIfExists: true)
            file("${af3_dir}/${companion}/${companion}.bin.zst", checkIfExists: true)
        }
        file("${af3_dir}/libcifpp/components.cif", checkIfExists: true)
    }

    ch_params_path = channel.value(file(colabfold2_params_path, type: 'dir', checkIfExists: true))

    emit:
    params_path = ch_params_path
}
