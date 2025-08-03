# RoseTTAFold2NA

| Mode                                                             | Protein | MSA server | Split MSA | RNA | Small-molecule | PTM  | Constraints | pLM |
|------------------------------------------------------------------|---------|------------|-----------|-----|----------------|------|-------------|-----|
| [RoseTTAFold2NA](https://github.com/uw-ipd/RoseTTAFold2NA)       |   ✅   |     ❌     |    ❌    | ✅  |       ❌       |  ❌ |     ❌     |  ❌ |

RoseTTAFold2NA can be run using the command below:

```bash
nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode rosettafold2na \
      --rosettafold2na_db <null (default) | DB_PATH> \
      --use_gpu \
      -profile <docker/singularity/.../institute>
```

## File Structure

The file structure of `--rosettafold2na_db` must be as follows: