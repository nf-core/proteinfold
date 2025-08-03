# ColabFold

| Mode                                                            | Protein | MSA server | Split MSA | RNA | Small-molecule | PTM  | Constraints | pLM |
|-----------------------------------------------------------------|---------|------------|-----------|-----|----------------|------|-------------|-----|
| [ColabFold](https://github.com/sokrypton/ColabFold)             |   ✅   |     ✅     |    ✅    | ❌  |       ❌       |  ❌ |     ❌     |  ❌ |

## General Usage

ColabFold mode can be run using the command below:

```console
nextflow run nf-core/proteinfold \
    --input samplesheet.csv \
    --outdir <OUTDIR> \
    --mode colabfold \
    --colabfold_db <null (default) | PATH> \
    --colabfold_model_preset "<alphafold2_ptm/alphafold2_multimer_v1/alphafold2_multimer_v2/alphafold2_multimer_v3>" \
    --use_gpu \
    -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
```

> [!WARNING]
> `--colabfold_model_preset` is used to infer how to handle multi-entry fasta files. Choosing `alphafold2_ptm` will result in a multi-entry fasta being processed as a series of monomer entries rather than as a single oligomeric complex.

By default, `--mode colabfold` will generate MSA files required for structure prediction using a local execution of the [ColabFold](https://github.com/sokrypton/ColabFold) search protocol. This protocol uses [MMseqs2](https://github.com/soedinglab/MMseqs2) to search a uniref30 expandable profile database and construct paired alignments using taxonomic labels. MSAs are enriched with additional unpaired sequences by searching an expandable profile databased of environmental sequences.

> [!NOTE]
> Local ColabFold search occurs in a separate module to model inference and the resulting MSA will be cached if downstream modules need to be re-run.

## File Structure

The file structure of `--colabfold_db` must be as follows:

<details markdown="1">
<summary>Directory structure</summary>
```
<colabfold_db>/
├── colabfold_envdb
│   ├── colabfold_envdb_202108_db
│   ├── colabfold_envdb_202108_db_aln
│   ├── colabfold_envdb_202108_db_aln.dbtype
│   └── ...
├── colabfold_uniref30
│   ├── uniref30_2302_db
│   ├── uniref30_2302_db_aln
│   ├── uniref30_2302_db_aln.dbtype
│   └── ...
└── params/
    └── alphafold_params_colab_2022-12-06/
        ├── LICENSE
        ├── params_model_1_multimer_v2.npz
        ├── params_model_1_multimer_v3.npz
        ├── params_model_1.npz
        ├── params_model_2_multimer_v2.npz
        ├── params_model_2_multimer_v3.npz
        ├── params_model_2.npz
        ├── params_model_3_multimer_v2.npz
        ├── params_model_3_multimer_v3.npz
        ├── params_model_3.npz
        ├── params_model_4_multimer_v2.npz
        ├── params_model_4_multimer_v3.npz
        ├── params_model_4.npz
        ├── params_model_5_multimer_v2.npz
        ├── params_model_5_multimer_v3.npz
        └── params_model_5.npz
```
</details>

If individual components are available at different locations in the filesystem, they can be set using the following flags:

```console
--colabfold_db_path </PATH/TO/colabfold_envdb/>
--colabfold_uniref30_path </PATH/TO/colabfold_uniref30/>
--colabfold_alphafold2_params_path </PATH/TO/params/>
```

Without setting the `--colabfold_db` flag, all of the required data files will be downloaded during the workflow execution.

> [!WARNING]
> The ColabFold reference sequence [databases](https://colabfold.mmseqs.com/) (uniref30_2302 and colabfold_envdb_202108) require ~1TB of disk space.

As an alternative, ColabFold MSAs can be generated without downloading the large reference sequence databases by calling the public MMSeqs API with the `--use_msa_server` argument. Users can also point to a private api endpoint using the `--msa_server_url` argument.

```console
nextflow run nf-core/proteinfold \
    --input samplesheet.csv \
    --outdir <OUTDIR> \
    --mode colabfold \
    --colabfold_db <PATH> \
    --colabfold_model_preset <alphafold2_ptm/alphafold2_multimer_v1/alphafold2_multimer_v2/alphafold2_multimer_v3> \
    --use_msa_server \
    --use_gpu \
    -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
```

> [!WARNING]
> If you aim to carry out a large number of predictions, please use the local mmseqs search module or setup and use your own custom MMSeqs2 API Server. You can find instructions [here](https://github.com/sokrypton/ColabFold/tree/main/MsaServer).

## Additional Arguments

See the [ColabFold](https://github.com/sokrypton/ColabFold) documentation for a full description of additional arguments. The arguments supported by the proteinfold workflow are described briefly below:

| Parameter                  | Default | Description                                         |
| -------------------------- | ------- | --------------------------------------------------- |
| `--num_recycles_colabfold` |   `3`   | The AlphaFold2 model used by ColabFold provides initial structure predictions as a recycled model input in an iterative refinement process. This parameter controls the number of times model outputs are recycled. Increasing the number of recycles has been found to improve performance for some challening cases.  |
| `--use_amber`              | `null`  | ColabFold outputs will sometimes contain phsyical violations such as steric clashes. These clashes can be resolved by post-processing the outputs with a short relaxation using the Amber Force Field. Non-clashing atoms are pinned to starting coordinates such that the relaxation has a minimal impact on final structures.   |

> You can override any of these parameters via the command line or a params file.