---
title: RoseTTAFold2NA
weight: 80
---

# RoseTTAFold2NA

| Mode                                                       | Split MSA | RNA | Small-molecule | PTM | Constraints | pLM | Protein | MSA server |
| :--------------------------------------------------------- | :-------: | :-: | :------------: | :-: | :---------: | :-: | :-----: | :--------: |
| [RoseTTAFold2NA](https://github.com/uw-ipd/RoseTTAFold2NA) |    ❌     | ✅  |       ❌       | ❌  |     ❌      | ❌  |   ✅    |     ❌     |

RoseTTAFold2NA can be run using the command below:

```bash
nextflow run nf-core/proteinfold \
      --input samplesheet.csv \
      --outdir <OUTDIR> \
      --mode rosettafold2na \
      --rosettafold2na_db <null (default) | DB_PATH> \
      --use_gpu \
      -profile <docker/singularity/.../institute>
```

> [!NOTE]
> RosettaFold2NA now expects each samplesheet row to reference a multi-chain FASTA that includes every interacting molecule. Add a `type=` hint to each header (for example `type=protein`, `type=rna`, `type=double_dna`, or `type=single_dna`) so the adaptor can tag chains with the correct RF2NA entity codes (`P`, `R`, `D`, `S`). If no hint is present, the chain type is inferred from sequence composition (pure `ACUGN` → RNA, pure `ACTGN` → DNA which defaults to `D` unless explicitly tagged single-strand, otherwise protein).

## File Structure

The file structure of `--rosettafold2na_db` must be as follows:

<details markdown="1">
<summary>Directory structure</summary>

```console
<rosettafold2na_db>/
├── bfd
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffdata
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffindex
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffdata
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffindex
│  ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffdata
│  └── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffindex
├── params
│  └── network
│     └── weights
│        └── RF2NA_apr23.pt
├── pdb100
│  ├── pdb100_2021Mar03_a3m.ffdata
│  ├── pdb100_2021Mar03_a3m.ffindex
│  ├── pdb100_2021Mar03_cs219.ffdata
│  ├── pdb100_2021Mar03_cs219.ffindex
│  ├── pdb100_2021Mar03_hhm.ffdata
│  ├── pdb100_2021Mar03_hhm.ffindex
│  ├── pdb100_2021Mar03_pdb.ffdata
│  └── pdb100_2021Mar03_pdb.ffindex
├── RNA
│  ├── Rfam.full_region
│  ├── Rfam.cm.*
│  ├── id_mapping.tsv.gz
│  ├── rfam_annotations.tsv.gz
│  ├── rnacentral.fasta.*
│  ├── nt.*
│  └── ...
└── UniRef30_2020_06
   ├── UniRef30_2020_06_a3m.ffdata
   ├── UniRef30_2020_06_a3m.ffindex
   ├── UniRef30_2020_06_cs219.ffdata
   ├── UniRef30_2020_06_cs219.ffindex
   ├── UniRef30_2020_06_hhm.ffdata
   ├── UniRef30_2020_06_hhm.ffindex
   └── UniRef30_2020_06.md5sums
```

</details>

If individual components are available at different locations in the filesystem, they can be set using the following flags:

```console
--rosettafold2na_uniref30_path </PATH/TO/UniRef30_2020_06/*>
--rosettafold2na_bfd_path </PATH/TO/bfd/*>
--rosettafold2na_pdb100_path </PATH/TO/pdb100/*>
--rosettafold2na_rna_path </PATH/TO/RNA/*>
--rosettafold2na_weights_path </PATH/TO/params/network/weights/RF2NA_apr23.pt>
```

Without setting the `--rosettafold2na_db` flag, all required data files will be downloaded during workflow execution.

> [!WARNING]
> RoseTTAFold2NA reference databases are large and require substantial local disk space.

## Input Format

RoseTTAFold2NA mode uses FASTA input from the samplesheet. Multi-entry FASTA files are supported.

To avoid ambiguity, annotate each FASTA header with a molecule type:

```console
>A type=protein
MSEQNNTEMTFQIQRIYTKDISFEAPNAPHVFQ...
>B type=rna
AUGGCUACG...
>C type=double_dna
ATGCGT...
>D type=single_dna
ATTTGCA...
```

Supported entity types are:

- `protein` (`P`)
- `rna` (`R`)
- `double_dna` (`D`)
- `single_dna` (`S`)
