# RoseTTAFold-All-Atom

| Mode                                                                              | Protein | MSA server | Split MSA | RNA | Small-molecule | PTM  | Constraints | pLM |
|-----------------------------------------------------------------------------------|---------|------------|-----------|-----|----------------|------|-------------|-----|
| [RoseTTAFold-All-Atom](https://github.com/baker-laboratory/RoseTTAFold-All-Atom/) |   ✅   |     ❌     |    ❌    | ✅  |       ✅       |  ✅ |     ❌     |  ❌ |

RoseTTAFold All-Atom can be run using the command below:

```bash
nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode rosettafold_all_atom \
      --rosettafold_all_atom_db <null (default) | DB_PATH> \
      --use_gpu \
      -profile <docker/singularity/.../institute>
```

## File Structure

The file structure of `--rosettafold_all_atom_db` must be as follows:

<details markdown="1">
<summary>Directory structure</summary>
```console
<rosettafold_all_atom_db>/
├── bfd
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffdata
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffindex
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffdata
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffindex
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffdata
│  └── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffindex
├── params
│   └── RFAA_paper_weights.pt
├── pdb100
│   ├── LICENSE
│   ├── pdb100_2021Mar03_a3m.ffdata
│   ├── pdb100_2021Mar03_a3m.ffindex
│   ├── pdb100_2021Mar03_cs219.ffdata
│   ├── pdb100_2021Mar03_cs219.ffindex
│   ├── pdb100_2021Mar03_hhm.ffdata
│   ├── pdb100_2021Mar03_hhm.ffindex
│   ├── pdb100_2021Mar03_pdb.ffdata
│   └── pdb100_2021Mar03_pdb.ffindex
└── uniref30
    ├── UniRef30_2023_02_a3m.ffdata
    ├── UniRef30_2023_02_a3m.ffindex
    ├── UniRef30_2023_02_cs219.ffdata
    ├── UniRef30_2023_02_cs219.ffindex
    ├── UniRef30_2023_02_hhm.ffdata
    ├── UniRef30_2023_02_hhm.ffindex
    └── UniRef30_2023_02.md5sums
```
</details>

If individual components are available at different locations in the filesystem, they can be set using the following flags:

```console
--bfd_rosettafold_all_atom_path </PATH/TO/bfd/> 
--rfaa_paper_weights_path </PATH/TO/params/RFAA_paper_weights.pt>
--uniref30_rosettafold_all_atom_path </PATH/TO/uniref30/>
--pdb100_rosettafold_all_atom_path </PATH/TO/pdb100/>
```

Without setting the `--rosettafold_all_atom_db` flag, all of the required data files will be downloaded during the workflow execution.

> [!WARNING]
> The RoseTTAFold-All-Atom reference databases require ~2TB of disk space.

## YAML format

RoseTTAFold-All-Atom allows modelling nucleic acids and small molecule ligands as well as specifying post-translational modifications. However, this input information is not supported in the FASTA format and must be specified in an input YAML file according to the RoseTTAFold-All-Atom [specification](https://github.com/baker-laboratory/RoseTTAFold-All-Atom?tab=readme-ov-file#predicting-protein-nucleic-acid-complexes).

RoseTTAFold-All-Atom YAML files can be run with proteinfold in rosettafold_all_atom mode by substituting the typical FASTA file in the input samplesheet.

```
id,fasta
T1024,T1024.yaml
```

> [!NOTE]
> Structures predicted from the RoseTTAFold-All-Atom YAML input will not be compatible with running multiple modes simultaneously.