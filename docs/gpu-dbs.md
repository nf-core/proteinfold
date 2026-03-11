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

Firstly, you must obtain the UniRef database. The database file is approx. 55GB. You may be able to get faster downloads by using `aria2c` with the `-x 8` option.

```bash
wget https://opendata.mmseqs.org/colabfold/uniref30_2302.db.tar.gz
tar xvf uniref30_2302.db.tar.gz
```

## Downloading the Colabfold EnvDB

Next, you will need to download the Colabfold EnvDB. This database is approx. 120GB.

```bash
wget https://opendata.mmseqs.org/colabfold/colabfold_envdb_202108.db.tar.gz
tar xvf colabfold_envdb_202108.db.tar.gz

```

## CPU Database structure

By now, your directory structure should look something like this
[T.B.D.]

## Create padded database

Next, we need to create the padded databases. For this, it is recommended to duplicate the databases.

```bash
mkdir colabfold_uniref30_padded
mmseqs makepaddedseqdb ./colabfold_uniref30/uniref30_2302_db_seq ./colabfold_uniref30_padded/uniref30_2302_db_seq
mmseqs makepaddedseqdb ./colabfold_uniref30/uniref30_2302_db ./colabfold_uniref30_padded/uniref30_2302_db
mkdir colabfold_envdb_padded
mmseqs makepaddedseqdb ./colabfold_envdb/colabfold_envdb_202108_db ./colabfold_envdb_padded/colabfold_envdb_202108_db
mmseqs makepaddedseqdb ./colabfold_envdb/colabfold_envdb_202108_db_seq ./colabfold_envdb_padded/colabfold_envdb_202108_db_seq
cp ./colabfold_envdb/colabfold_envdb_202108_db_aln.* ./colabfold_envdb_padded/
```

You should now have a directory structure that looks something similar to this

```
.
├── colabfold_envdb
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
│   ├── colabfold_envdb_202108_db_seq_h
│   ├── colabfold_envdb_202108_db_seq_h.dbtype
│   ├── colabfold_envdb_202108_db_seq_h.index
│   ├── colabfold_envdb_202108_db_seq.index
│   ├── colabfold_envdb_202108_sample_aln.tsv
│   ├── colabfold_envdb_202108_sample_h.tsv
│   ├── colabfold_envdb_202108_sample_seq.tsv
│   └── colabfold_envdb_202108_sample.tsv
├── colabfold_envdb_padded
│   ├── colabfold_envdb_202108_db
│   ├── colabfold_envdb_202108_db.dbtype
│   ├── colabfold_envdb_202108_db_h
│   ├── colabfold_envdb_202108_db_h.dbtype
│   ├── colabfold_envdb_202108_db_h.index
│   ├── colabfold_envdb_202108_db.index
│   ├── colabfold_envdb_202108_db.lookup
│   ├── colabfold_envdb_202108_db_seq
│   ├── colabfold_envdb_202108_db_seq.dbtype
│   ├── colabfold_envdb_202108_db_seq_h
│   ├── colabfold_envdb_202108_db_seq_h.dbtype
│   ├── colabfold_envdb_202108_db_seq_h.index
│   ├── colabfold_envdb_202108_db_seq.index
│   └── colabfold_envdb_202108_db_seq.lookup
├── colabfold_uniref30
│   ├── uniref30_2302_db
│   ├── uniref30_2302_db_aln
│   ├── uniref30_2302_db_aln.dbtype
│   ├── uniref30_2302_db_aln.index
│   ├── uniref30_2302_db.dbtype
│   ├── uniref30_2302_db.GPU_READY
│   ├── uniref30_2302_db_h
│   ├── uniref30_2302_db_h.dbtype
│   ├── uniref30_2302_db_h.index
│   ├── uniref30_2302_db.idx
│   ├── uniref30_2302_db.idx.dbtype
│   ├── uniref30_2302_db.idx.index
│   ├── uniref30_2302_db.index
│   ├── uniref30_2302_db.lookup
│   ├── uniref30_2302_db_mapping
│   ├── uniref30_2302_db_seq
│   ├── uniref30_2302_db_seq.dbtype
│   ├── uniref30_2302_db_seq_h
│   ├── uniref30_2302_db_seq_h.dbtype
│   ├── uniref30_2302_db_seq_h.index
│   ├── uniref30_2302_db_seq.index
│   └── uniref30_2302_db_taxonomy
└── colabfold_uniref30_padded
    ├── uniref30_2302_db
    ├── uniref30_2302_db.dbtype
    ├── uniref30_2302_db_h
    ├── uniref30_2302_db_h.dbtype
    ├── uniref30_2302_db_h.index
    ├── uniref30_2302_db.index
    ├── uniref30_2302_db.lookup
    ├── uniref30_2302_db_seq
    ├── uniref30_2302_db_seq.dbtype
    ├── uniref30_2302_db_seq_h
    ├── uniref30_2302_db_seq_h.dbtype
    ├── uniref30_2302_db_seq_h.index
    ├── uniref30_2302_db_seq.index
    └── uniref30_2302_db_seq.lookup
```

## Running colabfold

You will need to set the `--colabfold_enable_gpu_search true` flag. Below is an example command you can use to run with GPU search enabled:

```bash
nextflow run ./main.nf \
    --input "samplesheet.csv" \
    --outdir "output" \
    --mode "colabfold" \
    --use_gpu \
    --db /path/to/db/root \
    --use_msa_server false \
    --colabfold_enable_gpu_search true \
    --colabfold_model_preset alphafold2_ptm
```
