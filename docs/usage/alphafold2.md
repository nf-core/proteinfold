# AlphaFold2

| Mode                                                | Protein | RNA | Small-molecule | PTM | Constraints | pLM | MSA server | Split MSA |
| :-------------------------------------------------- | :-----: | :-: | :------------: | :-: | :---------: | :-: | :--------: | :-------: |
| [AlphaFold2](https://github.com/deepmind/alphafold) |   ✅    | ❌  |       ❌       | ❌  |     ❌      | ❌  |     ❌     |    ✅     |

AlphaFold2 can be run using the command below:

```bash
nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode alphafold2 \
      --alphafold2_db <null (default) | DB_PATH> \
      --use_gpu \
      --alphafold2_model_preset <monomer_ptm/monomer/monomer_casp14/multimer> \
      -profile <docker/singularity/.../institute>
```

> [!NOTE]
> By default, this will run a fork of AlphaFold2 where MSA generation is split from the neural network inference. This enables more efficient utilization of resources by allowing the CPU-bound MSA generation to be executed without occupying an idle GPU. If you want to run the original implementation of AlphaFold2 you can use the `--alphafold2_mode standard`.

> [!WARNING]
> `--alphafold2_model_preset <monomer_ptm/monomer/monomer_casp14/multimer>` is used to infer how to handle multi-entry fasta files. Choosing `monomer_ptm`, `monomer` or `monomer_casp14` will result in a multi-entry fasta being processed as a series of monomer entries rather than as a single oligomeric complex.

## File Structure

The file structure of `--alphafold2_db` must be as follows:

<details markdown="1">
<summary>Directory structure</summary>
```console
<alphafold2_db>/
├── bfd
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffdata
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffindex
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffdata
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffindex
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffdata
│  └── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffindex
├── params
│   └── alphafold_params_2022-12-06
│       ├── LICENSE
│       ├── params_model_1_multimer_v3.npz
│       ├── params_model_1.npz
│       ├── params_model_1_ptm.npz
│       ├── params_model_2_multimer_v3.npz
│       ├── params_model_2.npz
│       ├── params_model_2_ptm.npz
│       ├── params_model_3_multimer_v3.npz
│       ├── params_model_3.npz
│       ├── params_model_3_ptm.npz
│       ├── params_model_4_multimer_v3.npz
│       ├── params_model_4.npz
│       ├── params_model_4_ptm.npz
│       ├── params_model_5_multimer_v3.npz
│       ├── params_model_5.npz
│       └── params_model_5_ptm.npz
├── mgnify
│   └── mgy_clusters.fa
├── pdb70
│   ├── md5sum
│   ├── pdb70_a3m.ffdata
│   ├── pdb70_a3m.ffindex
│   ├── pdb70_clu.tsv
│   ├── pdb70_cs219.ffdata
│   ├── pdb70_cs219.ffindex
│   ├── pdb70_hhm.ffdata
│   ├── pdb70_hhm.ffindex
│   └── pdb_filter.dat
├── pdb_mmcif
│   ├── mmcif_files
│   │   ├── 1g6g.cif
│   │   ├── 1go4.cif
│   │   ├── 1isn.cif
│   │   ├── 1qgd.cif
│   │   ├── 1tp9.cif
│   │   ├── 4o2w.cif
│   │   ├── 6sg9.cif
│   │   ├── 6vi4.cif
│   │   ├── 7sp5.cif
│   │   └── ...
│   └── obsolete.dat
├── pdb_seqres
│   └── pdb_seqres.txt
├── small_bfd
│   └── bfd-first_non_consensus_sequences.fasta
├── uniprot
│   └── uniprot.fasta
├── uniref30
│   ├── UniRef30_2023_02_a3m.ffdata
│   ├── UniRef30_2023_02_a3m.ffindex
│   ├── UniRef30_2023_02_cs219.ffdata
│   ├── UniRef30_2023_02_cs219.ffindex
|   ├── UniRef30_2023_02_hhm.ffdata
│   ├── UniRef30_2023_02_hhm.ffindex
│   └── UniRef30_2023_02.md5sums
└── uniref90
    └── uniref90.fasta
```
</details>

If individual components are available at different locations in the filesystem, they can be set using the following flags:

```console
--bfd_path </PATH/TO/bfd/>
--alphafold2_small_bfd_path </PATH/TO/small_bfd/>
--alphafold2_params_path </PATH/TO/params/alphafold_params_*>
--alphafold2_mgnify_path </PATH/TO/mgnify/>
--pdb70_path </PATH/TO/pdb70/>
--alphafold2_pdb_mmcif_path </PATH/TO/pdb_mmcif/mmcif_files>
--pdb_obsolete_path </PATH/TO/pdb_mmcif/obsolete.dat>
--alphafold2_uniref30_path </PATH/TO/uniref30/>
--alphafold2_uniref90_path </PATH/TO/uniref90/>
--alphafold2_pdb_seqres_path </PATH/TO/pdb_seqres/>
--alphafold2_uniprot_path </PATH/TO/uniprot/>
```

Without setting the `--alphafold2_db` flag, all of the required data files will be downloaded during the workflow execution.

> [!WARNING]
> The AlphaFold2 reference databases require ~2TB of disk space.

## Additional Arguments

See the [AlphaFold2](https://github.com/google-deepmind/alphafold) documentation for a full description of additional arguments. The arguments supported by the proteinfold workflow are described briefly below:

| Parameter             | Default      | Description                                                                                                                                                                                                                                                                                                                                                                             |
| --------------------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--full_dbs`          | `false`      | bfd is a large environmental sequence database used to identify homologs. small bfd is a redundancy recuced version of the bfd database which can reduce the execution time of homolog search but may reduce the depth of the resulting MSA in some cases. `--full_dbs` ensures that the full version of bfd is used for search.                                                        |
| `--random_seed`       | `null`       | AlphaFold2 model inference is a stochastic process. Fixing a numerical random seed ensures that results are reproducible between runs.                                                                                                                                                                                                                                                  |
| `--max_template_date` | `2038-01-19` | Structural templates from the PDB are used as additional context when making predictions. Molecules with solved structures in the PDB can be trivially predicted by using these structures as inputs. When benchmarking model performance it can be useful to restrict the use of templates to those deposited before a fixed date to ensure solved structures do not bias predictions. |

> You can override any of these parameters via the command line or a params file.

> [!NOTE]
> Check the versions of the PDB data available on the infrastructure used to run proteinfold to determine template availability.
