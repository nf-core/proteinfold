process testSingularity {
    container = 'quay.io/patribota/proteinfold_rosettafold2na:dev'
    """
    singularity exec --nv docker://quay.io/patribota/proteinfold_rosettafold2na:dev nvidia-smi
    """
}

workflow {
    testSingularity()
}

