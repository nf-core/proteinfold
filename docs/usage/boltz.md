# Boltz

| Mode                                         | Protein | RNA | Small-molecule | PTM | Constraints | pLM | MSA server | Split MSA |
| :------------------------------------------- | :-----: | :-: | :------------: | :-: | :---------: | :-: | :--------: | :-------: |
| [Boltz](https://github.com/jwohlwend/boltz/) |   ✅    | ✅  |       ✅       | ✅  |     ✅      | ❌  |     ✅     |    ✅     |

## General Use

Boltz mode can be run using the command below:

```console
nextflow run nf-core/proteinfold \
    --input samplesheet.csv \
    --outdir <OUTDIR> \
    --mode boltz \
    --boltz_db <PATH> \
    --colabfold_db <PATH> \
    --use_gpu \
    -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
```

By default, `--mode boltz` will generate MSA files required for structure prediction using a local execution of the [ColabFold](https://github.com/sokrypton/ColabFold) search protocol. This protocol uses [MMseqs2](https://github.com/soedinglab/MMseqs2) to search a uniref30 expandable profile database and construct paired alignments using taxonomic labels. MSAs are enriched with additional unpaired sequences by searching an expandable profile databased of environmental sequences.

> [!NOTE]
> Local ColabFold search occurs in a separate module to model inference and the resulting MSA will be cached if downstream modules need to be re-run.

## File Structure

The file structure of `--boltz_db` must be as follows:

<details markdown="1">
<summary>Directory structure</summary>
```
<boltz_db>/
└── params
    ├── boltz1_conf.ckpt
    ├── boltz2_aff.ckpt
    ├── boltz2_conf.ckpt
    ├── ccd.pkl
    └── mols
```
</details>

If individual components are available at different locations in the filesystem, they can be set using the following flags:

```console
# Boltz-1
--boltz_ccd_path <PATH/TO/ccd.pkl>
--boltz_model_path </PATH/TO/boltz1_conf.ckpt>

# Boltz-2
--boltz2_aff_path </PATH/TO/boltz2_aff.ckpt>
--boltz2_conf_path </PATH/TO/boltz2_conf.ckpt>
--boltz2_mols_path </PATH/TO/mols/>
```

Similarly, the `--colabfold_db` flag must be set to run the local execution of ColabFold search. The file structure of `--colabfold_db` must be:

<details markdown="1">
<summary>Directory structure</summary>
```
<colabfold_db>/
├── colabfold_envdb
│   ├── colabfold_envdb_202108_db
│   ├── colabfold_envdb_202108_db_aln
│   ├── colabfold_envdb_202108_db_aln.dbtype
│   └── ...
└── colabfold_uniref30
    ├── uniref30_2302_db
    ├── uniref30_2302_db_aln
    ├── uniref30_2302_db_aln.dbtype
    └── ...
```
</details>

Without setting the `--boltz_db` and `--colabfold_db` flags, all of the required data files will be downloaded during the workflow execution.

> [!WARNING]
> The colabfold reference sequence [databases](https://colabfold.mmseqs.com/) (uniref30_2302 and colabfold_envdb_202108) require ~1TB of disk space.

As an alternative, Boltz MSAs can be generated without downloading the large reference sequence databases by calling the public MMSeqs API with the `--use_msa_server` argument. Users can also point to a private api endpoint using the `--msa_server_url` argument.

```console
nextflow run nf-core/proteinfold \
    --input samplesheet.csv \
    --outdir <OUTDIR> \
    --mode boltz \
    --boltz_db <PATH> \
    --use_msa_server \
    --use_gpu \
    -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
```

> [!WARNING]
> If you aim to carry out a large amount of predictions, please use the local mmseqs search module or setup and use your own custom MMSeqs2 API Server. You can find instructions [here](https://github.com/sokrypton/ColabFold/tree/main/MsaServer).

## General Molecules

Boltz can support general molecular structure prediction. The most direct way to indicate molecular type is to format FASTA files with the molecular type indicated in the sequence header:

```
>A|protein
QLEDSEVEAVAKGLEEM
>B|rna
AUGC
>C|smiles
N[C@@H](Cc1ccc(O)cc1)C(=O)O
>D|ccd
ATP
>E|dna
ATGC
```

If the molecule type is not specified in the header of the input fasta, proteinfold will try to guess the expected molecule type based on the character composition.

## YAML format

Boltz allows specifying post-translational modifications and manual distance constraints to guide predictions. However, this input information is not supported in the FASTA format and must be specified in an input YAML file according to the boltz [specification](https://github.com/jwohlwend/boltz/blob/main/docs/prediction.md#yaml-format).

Boltz YAML files can be run with proteinfold in boltz mode by substituting the typical FASTA file in the input samplesheet.

```
id,fasta
T1024,T1024.yaml
```

> [!NOTE]
> Structures predicted from the Boltz YAML input will not be compatible with running multiple modes simultaneously.

## Additional Arguments

See the [Boltz](https://github.com/jwohlwend/boltz) documentation for a full description of additional arguments. The arguments supported by the proteinfold workflow are described briefly below:

| Parameter                | Default  | Description                                                                                                                                                                                                                         |
| ------------------------ | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--boltz_model`          | `boltz2` | The model to use for prediction (boltz1 or boltz2)                                                                                                                                                                                  |
| `--boltz_use_potentials` | `false`  | Steering potentials are used by Boltz to improve the physical validity of output predictions (ie steric clashes, incorrect chirality etc). However, these potentials dramatically increase execution time and memory requirements.) |

> You can override any of these parameters via the command line or a params file.
