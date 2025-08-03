# AlphaFold3

| Mode                                                                              | Protein | RNA | Small-molecule | PTM  | Constraints | pLM | MSA server | Split MSA |
| :-------------------------------------------------------------------------------- | :----: | :--: | :------------: | :--: | :--------: | :--: | :---------: | :------: |
| [AlphaFold3](https://github.com/deepmind/alphafold)                               |   ✅   | ✅  |       ✅       |  ✅ |     ❌     |  ❌ |     ❌     |    ❌    |

> [!WARNING]
> The AlphaFold3 weights are not provided by this pipeline. Users must obtain the weights directly from DeepMind according to their [terms of use](https://github.com/deepmind/alphafold/blob/main/WEIGHTS_TERMS_OF_USE.md) and [prohibited use policy](https://github.com/deepmind/alphafold/blob/main/WEIGHTS_PROHIBITED_USE_POLICY.md). Please ensure you comply with all terms and conditions before using AlphaFold3. For more information about AlphaFold3 usage and requirements, please refer to the [official AlphaFold3 repository](https://github.com/deepmind/alphafold).

AlphaFold3 can be run using the command below:

```bash
nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode alphafold3 \
      --alphafold3_db <null (default) | DB_PATH> \
      --use_gpu \
      -profile <docker/singularity/.../institute>
```

The file structure of `--alphafold3_db` must be as follows:

<details markdown="1">
<summary>Directory structure</summary>
```console
├── mgnify
│   └── mgy_clusters_2022_05.fa
├── mmcif_files
│   ├── 1g6g.cif
│   ├── 1go4.cif
│   └── ...
├── params
│   └── af3.bin
├── pdb_seqres
│   └── pdb_seqres_2022_09_28.fasta
├── small_bfd
│   └── bfd-first_non_consensus_sequences.fasta
├── uniprot
│   └── uniprot_all_2021_04.fa
└── uniref90
    └── uniref90_2022_05.fa
```
</details>

> [!NOTE]
> The reference databases used by the workflow are those hosted by the AlphaFold3 implementation but the pipeline can be run with different versions of the same datasets.

If individual components are available at different locations in the filesystem, they can be set using the following flags:

```console
--alphafold3_small_bfd_path </PATH/TO/small_bfd/>
--alphafold3_params_path </PATH/TO/params/alphafold_params_*>
--alphafold3_mgnify_path </PATH/TO/mgnify/>
--pdb70_path </PATH/TO/pdb70/>
--alphafold3_pdb_mmcif_path </PATH/TO/pdb_mmcif/mmcif_files>
--alphafold3_uniref90_path </PATH/TO/uniref90/>
--alphafold3_pdb_seqres_path </PATH/TO/pdb_seqres/>
--alphafold3_uniprot_path </PATH/TO/uniprot/>
```

Without setting the `--alphafold3_db` flag, all of the required data files will be downloaded during the workflow execution.

> [!WARNING]
> The AlphaFold3 reference databases require ~2TB of disk space.