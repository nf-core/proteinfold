nextflow run main.nf --input /users/cn/lsantus/projects/proteinfold/test-datasets/testdata/samplesheet/v1.0/samplesheet.csv \
    --outdir /users/cn/lsantus/projects/proteinfold/nf_core_output\
    --mode AF2 \
    --af2_db /users/cn/abaltzis/db/alphafold \
    --full_dbs false \
    --skip_download true \
    --model_preset monomer \
    --use_gpu true \
    --standard_af2 false \
    -profile crg_gpu
