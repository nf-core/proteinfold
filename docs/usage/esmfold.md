# ESMFold

| Mode                                                                              | Protein | RNA | Small-molecule | PTM  | Constraints | pLM | MSA server | Split MSA |
| :-------------------------------------------------------------------------------- | :----: | :--: | :------------: | :--: | :--------: | :--: | :---------: | :------: |
| [ESMFold](https://github.com/facebookresearch/esm)                                |   ✅   | ❌  |       ❌       |  ❌ |     ❌     |  ✅ |     ❌     |    ❌    |

## General Usage

ESMFold mode can be run using the command below:

```console
nextflow run nf-core/proteinfold \
    --input samplesheet.csv \
    --outdir <OUTDIR> \
    --mode esmfold \
    --esmfold_model_preset <monomer/multimer> \
    --esmfold_db <null (default) | PATH> \
    --use_gpu \
    -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
```

> [!NOTE]
> ESMFold does not require searching large sequence databases for sequences homologous to the prediction target and instead relies on a pre-trained protein language model (pLM) to inform predictions.

> [!WARNING]
> `--esmfold_model_preset` is used to infer how to handle multi-entry fasta files. Choosing `monomer` will result in a multi-entry fasta being processed as a series of monomer entries rather than as a single oligomeric complex.

## File Structure

The file structure of `--esmfold_db` must be as follows:

<details markdown="1">
<summary>Directory structure</summary>
```
<esmfold_db>/params/
├── esm2_t36_3B_UR50D-contact-regression.pt
├── esm2_t36_3B_UR50D.pt
└── esmfold_3B_v1.pt
```
</details>

## Additional Arguments

See the [ESMFold](https://github.com/facebookresearch/esm) documentation for a full description of additional arguments. The arguments supported by the proteinfold workflow are described briefly below:

| Parameter                  | Default | Description                                         |
| -------------------------- | ------- | --------------------------------------------------- |
| `--num_recycles_esmfold`   |   `4`   | The ESMFold model provides initial structure predictions as a recycled model input in an iterative refinement process. This parameter controls the number of times model outputs are recycled. Increasing the number of recycles has been found to improve performance for some challening cases.  |

> You can override any of these parameters via the command line or a params file.