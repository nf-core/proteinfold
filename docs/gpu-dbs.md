# Using padded databases in proteinfold
Proteinfold can make use of GPU MSA search for faster searching. However, this requires creating padded databases for the GPU hardware you wish to use.

## Requirements
- mmseqs-gpu
- uniref30 database
- colabfold envdb database
- NVIDIA Ampere GPU or newer
- CUDA 12.4 or newer

## Database structure
Proteinfold can make use of the `--db` flag to load in all required databases. In order to load the padded databases, the database should be structured as such. Below is a truncated version of the database tree. It is important to note that the padded database files have the same prefix as the CPU files.
```
.
├── boltz1.ckpt
├── ccd.pkl
├── colabfold_envdb
│   ├── colabfold_envdb_202108_sample_h.tsv
│   ├── colabfold_envdb_202108_sample_seq.tsv
│   └── colabfold_envdb_202108_sample.tsv
├── colabfold_envdb_padded
│   ├── colabfold_envdb_202108_db_seq_h.index
│   ├── colabfold_envdb_202108_db_seq.index
│   └── colabfold_envdb_202108_db_seq.lookup
├── colabfold_uniref30
│   ├── uniref30_2302_db_seq_h.dbtype
│   ├── uniref30_2302_db_seq_h.index
│   ├── uniref30_2302_db_seq.index
│   └── uniref30_2302_db_taxonomy
├── colabfold_uniref30_gpu
│   ├── uniref30_2302_db.idx.index
│   ├── uniref30_2302_db.index
│   └── uniref30_2302_db.lookup
├── colabfold_uniref30.old
│   ├── uniref30_2302_db_seq.7
│   ├── uniref30_2302_db_seq.dbtype
│   └── uniref30_2302_db_seq.index
├── colabfold_uniref30_padded
│   ├── uniref30_2302_db_seq_h.index
│   ├── uniref30_2302_db_seq.index
│   └── uniref30_2302_db_taxonomy
├── mgnify
│   └── mgy_clusters.fa
├── pdb100
│   ├── pdb100_2021Mar03_pdb.ffdata
│   └── pdb100_2021Mar03_pdb.ffindex
├── pdb70
│   ├── pdb70_hhm.ffindex
│   └── pdb_filter.dat
├── pdb_mmcif
│   ├── mmcif_files
│   └── obsolete.dat
├── pdb_seqres
│   └── pdb_seqres.txt
├── rfam
│   └── Rfam-14.9_rep_seq.fasta
├── small_bfd
│   └── bfd-first_non_consensus_sequences.fasta
├── uniprot
│   └── uniprot.fasta
├── uniref30
│   └── UniRef30_2023_02_hhm.ffindex
└── uniref90
    └── uniref90.fasta
```

## Obtaining MMseqs-GPU
MMseqs has two x86 builds available for Linux. This requires the GPU version of MMseqs. It can be obtained via this command:

```bash
wget https://github.com/soedinglab/MMseqs2/releases/download/18-8cc5c/mmseqs-linux-gpu.tar.gz
tar xvf mmseqs-linux-gpu.tar.gz
```

## Downloading UniRef30 Database
Firstly, you must obtain the UniRef database. The database file is approx. 55GB.
```bash
wget https://opendata.mmseqs.org/colabfold/uniref30_2302.db.tar.gz
tar xvf uniref30_2302.db.tar.gz
```
