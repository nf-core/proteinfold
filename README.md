# ![nf-core/proteinfold](docs/images/nf-core-proteinfold_logo_light.png#gh-light-mode-only) ![nf-core/proteinfold](docs/images/nf-core-proteinfold_logo_dark.png#gh-dark-mode-only)

[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/proteinfold/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.7629995-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.7629995)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Nextflow Tower](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Nextflow%20Tower-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/nf-core/proteinfold)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23proteinfold-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/proteinfold)[![Follow on Twitter](http://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**nf-core/proteinfold** is a bioinformatics best-practice analysis pipeline for Protein 3D structure prediction pipeline.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources.The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/proteinfold/results).

## Pipeline summary

![Alt text](docs/images/nf-core-proteinfold_metro_map_1.1.0.png?raw=true "nf-core-proteinfold 1.1.0 metro map")

1. Choice of protein structure prediction method:

   i. [AlphaFold2](https://github.com/deepmind/alphafold)

   ii. [AlphaFold2 split](https://github.com/luisas/alphafold_split) - AlphaFold2 MSA computation and model inference in separate processes

   iii. [ColabFold](https://github.com/sokrypton/ColabFold) - MMseqs2 API server followed by ColabFold

   iv. [ColabFold](https://github.com/sokrypton/ColabFold) - MMseqs2 local search followed by ColabFold

   v. [ESMFold](https://github.com/facebookresearch/esm)

## Usage

> **Note**
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how
> to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline)
> with `-profile test` before running the workflow on actual data.

Now, you can run the pipeline using:

```bash
nextflow run nf-core/proteinfold \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

The pipeline takes care of downloading the required databases and parameters required by AlphaFold2, Colabfold or ESMFold. In case you have already downloaded the required files, you can skip this step by providing the path using the corresponding parameter [`--alphafold2_db`] or [`--colabfold_db`] or [`--esmfold_db`]

- Typical command to run AlphaFold2 mode:

  ```console
  nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode alphafold2 \
      --alphafold2_db <null (default) | DB_PATH> \
      --full_dbs <true/false> \
      --alphafold2_model_preset monomer \
      --use_gpu <true/false> \
      -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
  ```

- Typical command to run AlphaFold2 splitting the MSA from the prediction execution:

  ```console
  nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode alphafold2 \
      --alphafold2_mode split_msa_prediction \
      --alphafold2_db <null (default) | DB_PATH> \
      --full_dbs <true/false> \
      --alphafold2_model_preset monomer \
      --use_gpu <true/false> \
      -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
  ```

- Typical command to run colabfold_local mode:

  ```console
  nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode colabfold \
      --colabfold_server local \
      --colabfold_db <null (default) | PATH> \
      --num_recycle 3 \
      --use_amber <true/false> \
      --colabfold_model_preset "AlphaFold2-ptm" \
      --use_gpu <true/false> \
      --db_load_mode 0
      -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
  ```

- Typical command to run colabfold_webserver mode:

  ```console
  nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode colabfold \
      --colabfold_server webserver \
      --host_url <custom MMSeqs2 API Server URL> \
      --colabfold_db <null (default) | PATH> \
      --num_recycle 3 \
      --use_amber <true/false> \
      --colabfold_model_preset "AlphaFold2-ptm" \
      --use_gpu <true/false> \
      -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
  ```

  > **Warning**
  > If you aim to carry out a large amount of predictions using the colabfold_webserver mode, please setup and use your own custom MMSeqs2 API Server. You can find instructions [here](https://github.com/sokrypton/ColabFold/tree/main/MsaServer).

- Typical command to run esmfold mode:

  ```console
  nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode esmfold \
      --esmfold_model_preset <monomer/multimer> \
      --esmfold_db <null (default) | PATH> \
      --num_recycles 4 \
      --use_gpu <true/false> \
      -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
  ```

## Pipeline output

To see the the results of a test run with a full size dataset refer to the [results](https://nf-co.re/proteinfold/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/proteinfold/output).

## Credits

nf-core/proteinfold was originally written by Athanasios Baltzis ([@athbaltzis](https://github.com/athbaltzis)), Jose Espinosa-Carrasco ([@JoseEspinosa](https://github.com/JoseEspinosa)), Luisa Santus ([@luisas](https://github.com/luisas)) and Leila Mansouri ([@l-mansouri](https://github.com/l-mansouri)) from [The Comparative Bioinformatics Group](https://www.crg.eu/en/cedric_notredame) at [The Centre for Genomic Regulation, Spain](https://www.crg.eu/) under the umbrella of the [BovReg project](https://www.bovreg.eu/) and Harshil Patel ([@drpatelh](https://github.com/drpatelh)) from [Seqera Labs, Spain](https://seqera.io/).

We thank the following people for their extensive assistance in the development of this pipeline:

Many thanks to others who have helped out and contributed along the way too, including (but not limited to): Norman Goodacre and Waleed Osman from Interline Therapeutics ([@interlinetx](https://github.com/interlinetx)), Martin Steinegger ([@martin-steinegger](https://github.com/martin-steinegger)) and Raoul J.P. Bonnal ([@rjpbonnal](https://github.com/rjpbonnal))

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#proteinfold` channel](https://nfcore.slack.com/channels/proteinfold) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

If you use nf-core/proteinfold for your analysis, please cite it using the following doi: [10.5281/zenodo.7437038](https://doi.org/10.5281/zenodo.7437038)

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
