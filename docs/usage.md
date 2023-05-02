# nf-core/proteinfold: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/proteinfold/usage](https://nf-co.re/proteinfold/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

<!-- TODO nf-core: Add documentation about anything specific to running your pipeline. For general topics, please point to (and add to) the main nf-core website. -->

## Samplesheet input

You will need to create a samplesheet with information about the sequences you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 2 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

### Full samplesheet

The samplesheet can have as many columns as you desire, however, there is a strict requirement for the first 2 columns to match those defined in the table below.

A final samplesheet file may look something like the one below. This is for 2 sequences.

```console
sequence,fasta
T1024,https://raw.githubusercontent.com/nf-core/test-datasets/proteinfold/testdata/sequences/T1024.fasta
T1026,https://raw.githubusercontent.com/nf-core/test-datasets/proteinfold/testdata/sequences/T1026.fasta
```

| Column     | Description                                                                                         |
| ---------- | --------------------------------------------------------------------------------------------------- |
| `sequence` | Custom sequence name. Spaces in sequence names are automatically converted to underscores (`_`).    |
| `fasta`    | Full path to fasta file for the provided sequence. File has to have the extension ".fasta" or "fa". |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Running the pipeline

The typical commands for running the pipeline on AlphaFold2 and Colabfold modes are as follows:

```console
nextflow run nf-core/proteinfold \
       --input samplesheet.csv \
       --outdir <OUTDIR> \
       --mode alphafold2 \
       --alphafold2_db <null (default) | DB_PATH> \
       --full_dbs <true/false> \
       --alphafold2_model_preset monomer \
       --use_gpu <true/false> \
       -profile <docker>
```

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
If you specify the `--alphafold2_db ` parameter, the directory structure of your path should be like this:
```
├── mgnify
│   └── mgy_clusters_2018_12.fa
├── alphafold_params_2022-03-02
│   ├── LICENSE
│   ├── params_model_1_multimer.npz
│   ├── params_model_1_multimer_v2.npz
│   ├── params_model_1.npz
│   ├── params_model_1_ptm.npz
│   ├── params_model_2_multimer.npz
│   ├── params_model_2_multimer_v2.npz
│   ├── params_model_2.npz
│   ├── params_model_2_ptm.npz
│   ├── params_model_3_multimer.npz
│   ├── params_model_3_multimer_v2.npz
│   ├── params_model_3.npz
│   ├── params_model_3_ptm.npz
│   ├── params_model_4_multimer.npz
│   ├── params_model_4_multimer_v2.npz
│   ├── params_model_4.npz
│   ├── params_model_4_ptm.npz
│   ├── params_model_5_multimer.npz
│   ├── params_model_5_multimer_v2.npz
│   ├── params_model_5.npz
│   └── params_model_5_ptm.npz
├── pdb70
│   └── pdb70_from_mmcif_200916
│       ├── md5sum
│       ├── pdb70_a3m.ffdata
│       ├── pdb70_a3m.ffindex
│       ├── pdb70_clu.tsv
│       ├── pdb70_cs219.ffdata
│       ├── pdb70_cs219.ffindex
│       ├── pdb70_hhm.ffdata
│       ├── pdb70_hhm.ffindex
│       └── pdb_filter.dat
├── pdb_mmcif
│   ├── mmcif_files
│   │   ├── 1g6g.cif
│   │   ├── 1go4.cif
│   │   ├── 1isn.cif
│   │   ├── 1kuu.cif
│   │   ├── 1m7s.cif
│   │   ├── 1mwq.cif
│   │   ├── 1ni5.cif
│   │   ├── 1qgd.cif
│   │   ├── 1tp9.cif
│   │   ├── 1wa9.cif
│   │   ├── 1ye5.cif
│   │   ├── 1yhl.cif
│   │   ├── 2bjd.cif
│   │   ├── 2bo9.cif
│   │   ├── 2e7t.cif
│   │   ├── 2fyg.cif
│   │   ├── 2j0q.cif
│   │   ├── 2jcq.cif
│   │   ├── 2m4k.cif
│   │   ├── 2n9o.cif
│   │   ├── 2nsx.cif
│   │   ├── 2w4u.cif
│   │   ├── 2wd6.cif
│   │   ├── 2wh5.cif
│   │   ├── 2wji.cif
│   │   ├── 2yu3.cif
│   │   ├── 3cw2.cif
│   │   ├── 3d45.cif
│   │   ├── 3gnz.cif
│   │   ├── 3j0a.cif
│   │   ├── 3jaj.cif
│   │   ├── 3mzo.cif
│   │   ├── 3nrn.cif
│   │   ├── 3piv.cif
│   │   ├── 3pof.cif
│   │   ├── 3pvd.cif
│   │   ├── 3q45.cif
│   │   ├── 3qh6.cif
│   │   ├── 3rg2.cif
│   │   ├── 3sxe.cif
│   │   ├── 3uai.cif
│   │   ├── 3uid.cif
│   │   ├── 3wae.cif
│   │   ├── 3wt1.cif
│   │   ├── 3wtr.cif
│   │   ├── 3wy2.cif
│   │   ├── 3zud.cif
│   │   ├── 4bix.cif
│   │   ├── 4bzx.cif
│   │   ├── 4c1n.cif
│   │   ├── 4cej.cif
│   │   ├── 4chm.cif
│   │   ├── 4fzo.cif
│   │   ├── 4i1f.cif
│   │   ├── 4ioa.cif
│   │   ├── 4j6o.cif
│   │   ├── 4m9q.cif
│   │   ├── 4mal.cif
│   │   ├── 4nhe.cif
│   │   ├── 4o2w.cif
│   │   ├── 4pzo.cif
│   │   ├── 4qlx.cif
│   │   ├── 4uex.cif
│   │   ├── 4zm4.cif
│   │   ├── 4zv1.cif
│   │   ├── 5aj4.cif
│   │   ├── 5frs.cif
│   │   ├── 5hwo.cif
│   │   ├── 5kbk.cif
│   │   ├── 5odq.cif
│   │   ├── 5u5t.cif
│   │   ├── 5wzq.cif
│   │   ├── 5x9z.cif
│   │   ├── 5xe5.cif
│   │   ├── 5ynv.cif
│   │   ├── 5yud.cif
│   │   ├── 5z5c.cif
│   │   ├── 5zb3.cif
│   │   ├── 5zlg.cif
│   │   ├── 6a6i.cif
│   │   ├── 6az3.cif
│   │   ├── 6ban.cif
│   │   ├── 6g1f.cif
│   │   ├── 6ix4.cif
│   │   ├── 6jwp.cif
│   │   ├── 6ng9.cif
│   │   ├── 6ojj.cif
│   │   ├── 6s0x.cif
│   │   ├── 6sg9.cif
│   │   ├── 6vi4.cif
│   │   └── 7sp5.cif
│   └── obsolete.dat
├── pdb_seqres
│   └── pdb_seqres.txt
├── small_bfd
│   └── bfd-first_non_consensus_sequences.fasta
├── uniclust30
│   └── uniclust30_2018_08
│       ├── uniclust30_2018_08_a3m_db -> uniclust30_2018_08_a3m.ffdata
│       ├── uniclust30_2018_08_a3m_db.index
│       ├── uniclust30_2018_08_a3m.ffdata
│       ├── uniclust30_2018_08_a3m.ffindex
│       ├── uniclust30_2018_08.cs219
│       ├── uniclust30_2018_08_cs219.ffdata
│       ├── uniclust30_2018_08_cs219.ffindex
│       ├── uniclust30_2018_08.cs219.sizes
│       ├── uniclust30_2018_08_hhm_db -> uniclust30_2018_08_hhm.ffdata
│       ├── uniclust30_2018_08_hhm_db.index
│       ├── uniclust30_2018_08_hhm.ffdata
│       ├── uniclust30_2018_08_hhm.ffindex
│       └── uniclust30_2018_08_md5sum
├── uniprot
│   └── uniprot.fasta
└── uniref90
    └── uniref90.fasta
```

```console
nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode colabfold \
      --colabfold_server local \
      --colabfold_db <null (default) | DB_PATH> \
      --num_recycle 3 \
      --use_amber <true/false> \
      --colabfold_model_preset "AlphaFold2-ptm" \
      --use_gpu <true/false> \
      --db_load_mode 0
       -profile <docker>
```

```console
nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode colabfold
      --colabfold_server webserver \
      --host_url <custom MMSeqs2 API Server URL> \
      --colabfold_db <null (default) | DB_PATH> \
      --num_recycle 3 \
      --use_amber <true/false> \
      --colabfold_model_preset "AlphaFold2-ptm" \
      --use_gpu <true/false> \
       -profile <docker>
```

If you specify the `--colabfold_db ` parameter, the directory structure of your path should be like this:
```
├── colabfold_envdb_202108
│   ├── colabfold_envdb_202108_db.0
│   ├── colabfold_envdb_202108_db.1
│   ├── colabfold_envdb_202108_db.10
│   ├── colabfold_envdb_202108_db.11
│   ├── colabfold_envdb_202108_db.12
│   ├── colabfold_envdb_202108_db.13
│   ├── colabfold_envdb_202108_db.14
│   ├── colabfold_envdb_202108_db.15
│   ├── colabfold_envdb_202108_db.2
│   ├── colabfold_envdb_202108_db.3
│   ├── colabfold_envdb_202108_db.4
│   ├── colabfold_envdb_202108_db.5
│   ├── colabfold_envdb_202108_db.6
│   ├── colabfold_envdb_202108_db.7
│   ├── colabfold_envdb_202108_db.8
│   ├── colabfold_envdb_202108_db.9
│   ├── colabfold_envdb_202108_db_aln.0
│   ├── colabfold_envdb_202108_db_aln.1
│   ├── colabfold_envdb_202108_db_aln.10
│   ├── colabfold_envdb_202108_db_aln.11
│   ├── colabfold_envdb_202108_db_aln.12
│   ├── colabfold_envdb_202108_db_aln.13
│   ├── colabfold_envdb_202108_db_aln.14
│   ├── colabfold_envdb_202108_db_aln.15
│   ├── colabfold_envdb_202108_db_aln.2
│   ├── colabfold_envdb_202108_db_aln.3
│   ├── colabfold_envdb_202108_db_aln.4
│   ├── colabfold_envdb_202108_db_aln.5
│   ├── colabfold_envdb_202108_db_aln.6
│   ├── colabfold_envdb_202108_db_aln.7
│   ├── colabfold_envdb_202108_db_aln.8
│   ├── colabfold_envdb_202108_db_aln.9
│   ├── colabfold_envdb_202108_db_aln.dbtype
│   ├── colabfold_envdb_202108_db_aln.index
│   ├── colabfold_envdb_202108_db.dbtype
│   ├── colabfold_envdb_202108_db_h
│   ├── colabfold_envdb_202108_db_h.dbtype
│   ├── colabfold_envdb_202108_db_h.index
│   ├── colabfold_envdb_202108_db.idx
│   ├── colabfold_envdb_202108_db.idx.dbtype
│   ├── colabfold_envdb_202108_db.idx.index
│   ├── colabfold_envdb_202108_db.index
│   ├── colabfold_envdb_202108_db_seq.0
│   ├── colabfold_envdb_202108_db_seq.1
│   ├── colabfold_envdb_202108_db_seq.10
│   ├── colabfold_envdb_202108_db_seq.11
│   ├── colabfold_envdb_202108_db_seq.12
│   ├── colabfold_envdb_202108_db_seq.13
│   ├── colabfold_envdb_202108_db_seq.14
│   ├── colabfold_envdb_202108_db_seq.15
│   ├── colabfold_envdb_202108_db_seq.2
│   ├── colabfold_envdb_202108_db_seq.3
│   ├── colabfold_envdb_202108_db_seq.4
│   ├── colabfold_envdb_202108_db_seq.5
│   ├── colabfold_envdb_202108_db_seq.6
│   ├── colabfold_envdb_202108_db_seq.7
│   ├── colabfold_envdb_202108_db_seq.8
│   ├── colabfold_envdb_202108_db_seq.9
│   ├── colabfold_envdb_202108_db_seq.dbtype
│   ├── colabfold_envdb_202108_db_seq_h -> colabfold_envdb_202108_db_h
│   ├── colabfold_envdb_202108_db_seq_h.dbtype -> colabfold_envdb_202108_db_h.dbtype
│   ├── colabfold_envdb_202108_db_seq_h.index -> colabfold_envdb_202108_db_h.index
│   ├── colabfold_envdb_202108_db_seq.index
├── params
│   ├── alphafold_params_2021-07-14
│   │   ├── LICENSE
│   │   ├── params_model_1.npz
│   │   ├── params_model_1_ptm.npz
│   │   ├── params_model_2.npz
│   │   ├── params_model_2_ptm.npz
│   │   ├── params_model_3.npz
│   │   ├── params_model_3_ptm.npz
│   │   ├── params_model_4.npz
│   │   ├── params_model_4_ptm.npz
│   │   ├── params_model_5.npz
│   │   └── params_model_5_ptm.npz
│   └── alphafold_params_colab_2022-03-02
│       ├── LICENSE
│       ├── params_model_1_multimer_v2.npz
│       ├── params_model_1.npz
│       ├── params_model_2_multimer_v2.npz
│       ├── params_model_2.npz
│       ├── params_model_2_ptm.npz
│       ├── params_model_3_multimer_v2.npz
│       ├── params_model_3.npz
│       ├── params_model_4_multimer_v2.npz
│       ├── params_model_4.npz
│       ├── params_model_5_multimer_v2.npz
│       └── params_model_5.npz
└── uniref30_2202
    ├── uniref30_2202_db.0
    ├── uniref30_2202_db.1
    ├── uniref30_2202_db.2
    ├── uniref30_2202_db.3
    ├── uniref30_2202_db.4
    ├── uniref30_2202_db.5
    ├── uniref30_2202_db.6
    ├── uniref30_2202_db.7
    ├── uniref30_2202_db_aln.0
    ├── uniref30_2202_db_aln.1
    ├── uniref30_2202_db_aln.2
    ├── uniref30_2202_db_aln.3
    ├── uniref30_2202_db_aln.4
    ├── uniref30_2202_db_aln.5
    ├── uniref30_2202_db_aln.6
    ├── uniref30_2202_db_aln.7
    ├── uniref30_2202_db_aln.dbtype
    ├── uniref30_2202_db_aln.index
    ├── uniref30_2202_db.dbtype
    ├── uniref30_2202_db_h
    ├── uniref30_2202_db_h.dbtype
    ├── uniref30_2202_db_h.index
    ├── uniref30_2202_db.idx
    ├── uniref30_2202_db.idx.dbtype
    ├── uniref30_2202_db.idx.index
    ├── uniref30_2202_db.index
    ├── uniref30_2202_db_seq.0
    ├── uniref30_2202_db_seq.1
    ├── uniref30_2202_db_seq.2
    ├── uniref30_2202_db_seq.3
    ├── uniref30_2202_db_seq.4
    ├── uniref30_2202_db_seq.5
    ├── uniref30_2202_db_seq.6
    ├── uniref30_2202_db_seq.7
    ├── uniref30_2202_db_seq.dbtype
    ├── uniref30_2202_db_seq_h -> uniref30_2202_db_h
    ├── uniref30_2202_db_seq_h.dbtype -> uniref30_2202_db_h.dbtype
    ├── uniref30_2202_db_seq_h.index -> uniref30_2202_db_h.index
    └── uniref30_2202_db_seq.index
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.



Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/proteinfold
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/proteinfold releases page](https://github.com/nf-core/proteinfold/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

## Core Nextflow arguments

> **NB:** These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Conda) - see below.

> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter or Charliecloud.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

For example, if the nf-core/rnaseq pipeline is failing after multiple re-submissions of the `STAR_ALIGN` process due to an exit code of `137` this would indicate that there is an out of memory issue:

```console
[62/149eb0] NOTE: Process `NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN (WT_REP1)` terminated with an error exit status (137) -- Execution is retried (1)
Error executing process > 'NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN (WT_REP1)'

Caused by:
    Process `NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN (WT_REP1)` terminated with an error exit status (137)

Command executed:
    STAR \
        --genomeDir star \
        --readFilesIn WT_REP1_trimmed.fq.gz  \
        --runThreadN 2 \
        --outFileNamePrefix WT_REP1. \
        <TRUNCATED>

Command exit status:
    137

Command output:
    (empty)

Command error:
    .command.sh: line 9:  30 Killed    STAR --genomeDir star --readFilesIn WT_REP1_trimmed.fq.gz --runThreadN 2 --outFileNamePrefix WT_REP1. <TRUNCATED>
Work dir:
    /home/pipelinetest/work/9d/172ca5881234073e8d76f2a19c88fb

Tip: you can replicate the issue by changing to the process work dir and entering the command `bash .command.run`
```

#### For beginners

A first step to bypass this error, you could try to increase the amount of CPUs, memory, and time for the whole pipeline. Therefor you can try to increase the resource for the parameters `--max_cpus`, `--max_memory`, and `--max_time`. Based on the error above, you have to increase the amount of memory. Therefore you can go to the [parameter documentation of rnaseq](https://nf-co.re/rnaseq/3.9/parameters) and scroll down to the `show hidden parameter` button to get the default value for `--max_memory`. In this case 128GB, you than can try to run your pipeline again with `--max_memory 200GB -resume` to skip all process, that were already calculated. If you can not increase the resource of the complete pipeline, you can try to adapt the resource for a single process as mentioned below.

#### Advanced option on process level

To bypass this error you would need to find exactly which resources are set by the `STAR_ALIGN` process. The quickest way is to search for `process STAR_ALIGN` in the [nf-core/rnaseq Github repo](https://github.com/nf-core/rnaseq/search?q=process+STAR_ALIGN).
We have standardised the structure of Nextflow DSL2 pipelines such that all module files will be present in the `modules/` directory and so, based on the search results, the file we want is `modules/nf-core/star/align/main.nf`.
If you click on the link to that file you will notice that there is a `label` directive at the top of the module that is set to [`label process_high`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/modules/nf-core/software/star/align/main.nf#L9).
The [Nextflow `label`](https://www.nextflow.io/docs/latest/process.html#label) directive allows us to organise workflow processes in separate groups which can be referenced in a configuration file to select and configure subset of processes having similar computing requirements.
The default values for the `process_high` label are set in the pipeline's [`base.config`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L33-L37) which in this case is defined as 72GB.
Providing you haven't set any other standard nf-core parameters to **cap** the [maximum resources](https://nf-co.re/usage/configuration#max-resources) used by the pipeline then we can try and bypass the `STAR_ALIGN` process failure by creating a custom config file that sets at least 72GB of memory, in this case increased to 100GB.
The custom config below can then be provided to the pipeline via the [`-c`](#-c) parameter as highlighted in previous sections.

```nextflow
process {
    withName: 'NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN' {
        memory = 100.GB
    }
}
```

> **NB:** We specify the full process name i.e. `NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN` in the config file because this takes priority over the short name (`STAR_ALIGN`) and allows existing configuration using the full process name to be correctly overridden.
>
> If you get a warning suggesting that the process selector isn't recognised check that the process name has been specified correctly.

### Updating containers (advanced users)

The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. If for some reason you need to use a different version of a particular tool with the pipeline then you just need to identify the `process` name and override the Nextflow `container` definition for that process using the `withName` declaration. For example, in the [nf-core/viralrecon](https://nf-co.re/viralrecon) pipeline a tool called [Pangolin](https://github.com/cov-lineages/pangolin) has been used during the COVID-19 pandemic to assign lineages to SARS-CoV-2 genome sequenced samples. Given that the lineage assignments change quite frequently it doesn't make sense to re-release the nf-core/viralrecon everytime a new version of Pangolin has been released. However, you can override the default container used by the pipeline by creating a custom config file and passing it as a command-line argument via `-c custom.config`.

1. Check the default version used by the pipeline in the module file for [Pangolin](https://github.com/nf-core/viralrecon/blob/a85d5969f9025409e3618d6c280ef15ce417df65/modules/nf-core/software/pangolin/main.nf#L14-L19)
2. Find the latest version of the Biocontainer available on [Quay.io](https://quay.io/repository/biocontainers/pangolin?tag=latest&tab=tags)
3. Create the custom config accordingly:

   - For Docker:

     ```nextflow
     process {
         withName: PANGOLIN {
             container = 'quay.io/biocontainers/pangolin:3.0.5--pyhdfd78af_0'
         }
     }
     ```

   - For Singularity:

     ```nextflow
     process {
         withName: PANGOLIN {
             container = 'https://depot.galaxyproject.org/singularity/pangolin:3.0.5--pyhdfd78af_0'
         }
     }
     ```

   - For Conda:

     ```nextflow
     process {
         withName: PANGOLIN {
             conda = 'bioconda::pangolin=3.0.5'
         }
     }
     ```

> **NB:** If you wish to periodically update individual tool-specific results (e.g. Pangolin) generated by the pipeline then you must ensure to keep the `work/` directory otherwise the `-resume` ability of the pipeline will be compromised and it will restart from scratch.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Use of shared file systems

Given that the AlphaFold2 and the ColabFold modes (except for the ColabFold webserver option) rely on huge databases to infer the predictions, the execution of the pipeline is recommended to take place on shared file systems so as to avoid high latency caused during staging this data. For instance, if you work on AWS, you might consider using an Amazon FSx file system.

## Azure Resource Requests

To be used with the `azurebatch` profile by specifying the `-profile azurebatch`.
We recommend providing a compute `params.vm_type` of `Standard_D16_v3` VMs by default but these options can be changed if required.

Note that the choice of VM size depends on your quota and the overall workload during the analysis.
For a thorough list, please refer the [Azure Sizes for virtual machines in Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
