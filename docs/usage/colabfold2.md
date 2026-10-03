---
title: ColabFold2
weight: 25
---

# ColabFold2

| Mode                                                 | Protein | RNA | Small-molecule | PTM | Constraints | pLM | MSA server | Split MSA |
| :--------------------------------------------------- | :-----: | :-: | :------------: | :-: | :---------: | :-: | :--------: | :-------: |
| [ColabFold2](https://github.com/sokrypton/ColabFold) |   ✅    | ✅  |       ✅       | ✅  |     ❌      | ✅  |     ✅     |    ❌     |

> [!WARNING]
> ColabFold2 support is experimental and its upstream interfaces may change. Which entities a backend actually supports is decided by that backend.

## General Usage

A ColabFold2 backend is selected with `--mode`. Only one ColabFold2 backend can be run per invocation.

| Mode token              | Upstream model type |
| ----------------------- | ------------------- |
| `colabfold2-alphafold3` | `alphafold3`        |
| `colabfold2-boltz2`     | `boltz2`            |
| `esmfold2`              | `esmfold2*`         |
| `protenix2`             | `protenix2`         |
| `chai1`                 | `chai1`             |
| `intellifold2`          | `intellifold2`      |
| `opendde`               | `opendde`           |
| `openfold3`             | `openfold3`         |
| `openbind0`             | `openbind0`         |
| `rosettafold3`          | `rosettafold3`      |

```console
nextflow run nf-core/proteinfold \
    --input samplesheet.csv \
    --outdir <OUTDIR> \
    --mode colabfold2-alphafold3 \
    --colabfold_db <null (default) | PATH> \
    --use_gpu \
    -profile <docker/singularity/podman/shifter/charliecloud/institute>
```

FASTA inputs go through the local `colabfold_search` protocol against the databases in `--colabfold_db`. AlphaFold3 JSON inputs are passed through to carry rich entities such as RNA, ligands, PTMs, templates and user CCD definitions: with offline MSA generation the pipeline extracts their protein queries, runs the search and merges the resulting MSAs back into the original JSON, while `--use_msa_server` (with an optional private `--msa_server_url`) passes the file directly to `colabfold_batch`.

> [!NOTE]
> Local ColabFold search occurs in a separate module to model inference and the resulting MSA will be cached if downstream modules need to be re-run.

## File Structure

The file structure of the ColabFold2 weights root (`<colabfold_db>/colabfold2_models` by default, or `--colabfold2_params_path`; the latter is required when using `--use_msa_server` without `--colabfold_db`) must be as follows:

<details markdown="1">
<summary>Directory structure</summary>

```
<colabfold2_params_path>/params/af3/
├── libcifpp/
│   └── components.cif
├── esmc_300m|esmc_600m/
│   └── <variant>.bin.zst
└── <model>[-int8]/
    ├── <model>.bin.zst
    ├── <model>.lm.npz
    └── download_<model>_<precision>_finished.txt
```

</details>

`<model>` is the selected upstream model, suffixed with `-int8` when `--colabfold2_weights_precision int8` is set; the `<model>.lm.npz` checkpoint and matching `esmc_300m` or `esmc_600m` trunk are only required by the ESMFold2 language-model selections.

## Additional Arguments

See the [ColabFold2](https://github.com/sokrypton/ColabFold) documentation for a full description of additional arguments. The arguments supported by the proteinfold workflow are described briefly below:

| Parameter                        | Default | Description                                                                                                                                                                                                                                  |
| -------------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--colabfold2_weights_precision` | `fp32`  | Checkpoint precision: `fp32` or `int8`. Official AlphaFold3 weights support `fp32` only.                                                                                                                                                     |
| `--esmfold2_model`               | `msa`   | ESMFold2 checkpoint: `msa`, `lm300m` or `lm600m`. The language-model selections pass `--use-esm` automatically and provide no confidence outputs.                                                                                            |
| `--colabfold2_kernel_backend`    | `auto`  | Fused-kernel implementation used by `colabfold_batch`; `auto` is the upstream default, but on GPUs missing from the bundled JAX device table (e.g. L40S, V100) it fails with `No supported GPU devices found` and `cuda_legacy` must be set. |
| `--colabfold_num_recycles`       | `3`     | The number of times model outputs are recycled as iterative refinement input. This parameter is shared with the ColabFold mode.                                                                                                              |

> You can override any of these parameters via the command line or a params file.
