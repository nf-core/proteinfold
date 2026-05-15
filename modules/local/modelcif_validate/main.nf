process MODELCIF_VALIDATE {
    tag "$meta.id-$meta.model"
    label 'process_single'

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(mmcif)

    output:
    tuple val(meta), path(mmcif), emit: modelcif
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    #!/usr/bin/env python3
    import warnings
    import modelcif.reader
    import sys

    files = "${mmcif}".split()
    for f in files:
        with warnings.catch_warnings():
            warnings.filterwarnings('error')
            with open(f) as fh:
                systems = modelcif.reader.read(fh)
        if not systems:
            raise ValueError(f"No ModelCIF system found in {f}")
        print(f'py-modelcif validation passed: {f}', file=sys.stderr)

    with open('versions.yml', 'w') as fh:
        import modelcif
        fh.write('${task.process}:\\n')
        fh.write(f'    modelcif: {modelcif.__version__}\\n')
        import platform
        fh.write(f'    python: {platform.python_version()}\\n')
    """

}
