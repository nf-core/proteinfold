process PREPARE_MMSEQS_DB {
    tag "$meta.id"
    label "process_medium"

    container "/srv/scratch/sbf/containers/mmseqs-gpu.sif"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("querydb")

    script:
    """
    mkdir "querydb"
    /app/mmseqs/bin/mmseqs createdb "${fasta}" ./querydb/${meta.id}
    """
}

process SEARCH_MMSEQS_GPU {
    tag "$meta.id"
    label "process_medium"
    label "process_gpu"

    container "/srv/scratch/sbf/containers/mmseqs-gpu.sif"

    input:
    tuple val(meta), path(fasta), path(querydb)
    path ("mmseqs-gpu")

    output:
    tuple val(meta), path ("colabfold_${meta.id}_hits.a3m")

    script:
    """
    mkdir "msas"
    /app/mmseqs/bin/mmseqs search \
        --gpu 1 \
        ./${querydb}/${meta.id} \
        ./mmseqs-gpu/colabfold_envdb_202108_db \
        ./msas/colabfold_${meta.id} \
        ./tmp

    # Convert to a3m files
    mkdir "msa_inter"
    mkdir "tmp_out"
    /app/mmseqs/bin/mmseqs result2msa \
        ./querydb/${meta.id} \
        ./mmseqs-gpu/colabfold_envdb_202108_db \
        ./msas/colabfold_${meta.id} \
        ./msa_inter/colabfold_${meta.id}
    /app/mmseqs/bin/mmseqs unpackdb \
        ./msa_inter/colabfold_${meta.id} ./tmp_out/colabfold_${meta.id}
    mv ./tmp_out/colabfold_${meta.id}/0 ./colabfold_${meta.id}_hits.a3m
    """
}
