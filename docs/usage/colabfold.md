---
title: ColabFold
weight: 40
---

# ColabFold

| Mode                                                | Protein | RNA | Small-molecule | PTM | Constraints | pLM | MSA server | Split MSA |
| :-------------------------------------------------- | :-----: | :-: | :------------: | :-: | :---------: | :-: | :--------: | :-------: |
| [ColabFold](https://github.com/sokrypton/ColabFold) |   ✅    | ❌  |       ❌       | ❌  |     ❌      | ❌  |     ✅     |    ✅     |

## General Usage

ColabFold mode can be run using the command below:

```console
nextflow run nf-core/proteinfold \
    --input samplesheet.csv \
    --outdir <OUTDIR> \
    --mode colabfold \
    --colabfold_db <null (default) | PATH> \
    --use_gpu \
    -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
```

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
    └── alphafold_params_2022-12-06/
        ├── LICENSE
        ├── params_model_1_multimer_v3.npz
        ├── params_model_1.npz
        ├── params_model_1_ptm.npz
        ├── params_model_2_multimer_v3.npz
        ├── params_model_2.npz
        ├── params_model_2_ptm.npz
        ├── params_model_3_multimer_v3.npz
        ├── params_model_3.npz
        ├── params_model_3_ptm.npz
        ├── params_model_4_multimer_v3.npz
        ├── params_model_4.npz
        ├── params_model_4_ptm.npz
        ├── params_model_5_multimer_v3.npz
        ├── params_model_5.npz
        └── params_model_5_ptm.npz
```

</details>

If individual components are available at different locations in the filesystem, they can be set using the following flags:

```console
--colabfold_envdb_path </PATH/TO/colabfold_envdb/*>
--colabfold_uniref30_path </PATH/TO/colabfold_uniref30/*>
--colabfold_alphafold2_params_path </PATH/TO/params/alphafold_params_colab_2022-12-06/>
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
    --use_msa_server \
    --use_gpu \
    -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
```

> [!WARNING]
> If you aim to carry out a large number of predictions, please use the local mmseqs search module or setup and use your own custom MMSeqs2 API Server. You can find instructions [here](https://github.com/sokrypton/ColabFold/tree/main/MsaServer).

## Additional Arguments

See the [ColabFold](https://github.com/sokrypton/ColabFold) documentation for a full description of additional arguments. The arguments supported by the proteinfold workflow are described briefly below:

| Parameter                              | Default                       | Description                                                                                                                                                                                                                                                                                                                     |
| -------------------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--colabfold_num_recycles`             | `3`                           | The AlphaFold2 model used by ColabFold provides initial structure predictions as a recycled model input in an iterative refinement process. This parameter controls the number of times model outputs are recycled. Increasing the number of recycles has been found to improve performance for some challening cases.          |
| `--colabfold_use_amber`                | `true`                        | ColabFold outputs will sometimes contain phsyical violations such as steric clashes. These clashes can be resolved by post-processing the outputs with a short relaxation using the Amber Force Field. Non-clashing atoms are pinned to starting coordinates such that the relaxation has a minimal impact on final structures. |
| `--colabfold_db_load_mode`             | `0`                           | Specify the way that MMSeqs2 will load the required databases in memory                                                                                                                                                                                                                                                         |
| `--colabfold_alphafold2_params_prefix` | `alphafold_params_2022-12-06` | Specify the alphafold2 params used for prediction.                                                                                                                                                                                                                                                                              |
| `--colabfold_use_templates`            | `false`                       | Use PDB templates to support predictions. The ColabFold notebooks do not use templates by default.                                                                                                                                                                                                                              |
| `--colabfold_create_index`             | `false`                       | Create index for ColabFold databases during setup. On network filesystems it can be more performant to re-compute the index on the fly                                                                                                                                                                                          |

> You can override any of these parameters via the command line or a params file.
