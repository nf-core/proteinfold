# HelixFold3

| Mode                                                                              | Protein | RNA | Small-molecule | PTM  | Constraints | pLM | MSA server | Split MSA |
| :-------------------------------------------------------------------------------- | :----: | :--: | :------------: | :--: | :--------: | :--: | :---------: | :------: |
| [HelixFold3](https://github.com/PaddlePaddle/PaddleHelix/tree/dev/apps/protein_folding/helixfold3) | ✅ | ✅ | ✅ |  ❌ |     ❌     |  ❌ |     ❌     |    ❌    |

## General Usage

HelixFold3 mode can be run using the command below:

```console
nextflow run nf-core/proteinfold \
    --input samplesheet.csv \
    --outdir <OUTDIR> \
    --mode helixfold3 \
    --helixfold3_db <null (default) | PATH> \
    --use_gpu \
    -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
```

## File Structure

The file structure of `--helixfold3_db` must be as follows:

<details markdown="1">
<summary>Directory structure</summary>
```
<helixfold3_db>/
├── bfd
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffdata
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffindex
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffdata
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffindex
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffdata
│   └── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffindex
├── maxit-v11.200-prod-src
│   ├── annotation-v1.0
│   └── ...
├── mgnify
│   └── mgy_clusters.fa
├── params
│   ├── ccd_preprocessed_etkdg.pkl.gz
│   └── HelixFold3-240814.pdparams
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
│   ├── UniRef30_2023_02_a3m.ffdata
│   ├── UniRef30_2023_02_a3m.ffindex
│   ├── UniRef30_2023_02_cs219.ffdata
│   ├── UniRef30_2023_02_cs219.ffindex
│   ├── UniRef30_2023_02_hhm.ffdata
│   ├── UniRef30_2023_02_hhm.ffindex
│   └── UniRef30_2023_02.md5sums
└── uniref90
    └── uniref90.fasta
```
</details>

If individual components are available at different locations in the filesystem, they can be set using the following flags:

```console
--helixfold3_init_models_path </PATH/TO/params/HelixFold3-240814.pdparams>
--helixfold3_ccd_preprocessed_path </PATH/TO/params/ccd_preprocessed_etkdg.pkl.gz>
--helixfold3_rfam_path </PATH/TO/rfam/Rfam-14.9_rep_seq.fasta>
--helixfold3_maxit_src_path </PATH/TO/maxit-v11.200-prod-src>
--helixfold3_bfd_path </PATH/TO/bfd/>
--helixfold3_small_bfd_path </PATH/TO/small_bfd/>
--helixfold3_mgnify_path </PATH/TO/mgnify/>
--helixfold3_pdb_mmcif_path </PATH/TO/pdb_mmcif/mmcif_files>
--helixfold3_obsolete_path </PATH/TO/pdb_mmcif/obsolete.dat>
--helixfold3_uniclust30_path </PATH/TO/uniref30/>
--helixfold3_uniref90_path </PATH/TO/uniref90/>
--helixfold3_pdb_seqres_path </PATH/TO/pdb_seqres/>
--helixfold3_uniprot_path </PATH/TO/uniprot/>
```

Without setting the `--helixfold3_db` flag, all of the required data files will be downloaded during the workflow execution.

> [!WARNING]
> The HelixFold3 reference sequence databases require ~2TB of disk space.

## JSON format

HelixFold3 supports modelling of general molecular structures. Currently, only protein entities are supported using the FASTA format. Non-protein entities must be specified in an input JSON file according to the HelixFold3 [specification](https://github.com/PaddlePaddle/PaddleHelix/tree/dev/apps/protein_folding/helixfold3#-understanding-model-input).

HelixFold3 JSON files can be run with proteinfold in helixfold3 mode by substituting the typical FASTA file in the input samplesheet.

```
id,fasta
T1024,T1024.json
```

> [!NOTE]
> Structures predicted from the helixfold3 json input will not be compatible with running multiple modes simultaneously.

## Additional Parameters

See the [HelixFold3](https://github.com/PaddlePaddle/PaddleHelix/tree/dev/apps/protein_folding/helixfold3#-running-helixfold-for-inference) documentation for a full description of additional arguments. The arguments supported by the proteinfold workflow are described briefly below:

| Parameter               | Default       | Description                                         |
| ----------------------- | ------------- | --------------------------------------------------- |
| `--max_template_date`   | `2038-01-19`  | Structural templates from the PDB are used as additional context when making predictions. Molecules with solved structures in the PDB can be trivially predicted by using these structures as inputs. When benchmarking model performance it can be useful to restrict the use of templates to those deposited before a fixed date to ensure solved structures do not bias predictions.  |
| `--preset`              | `reduced_dbs` | bfd is a large environmental sequence database used to identify homologs. small bfd is a redundancy recuced version of the bfd database which can reduce execution time of homolog search but may reduce the depth of the resulting MSA in some cases. `--preset` controls the version of bfd used for search. (reduced_dbs/full_dbs)  |
| `--precision`           |   `bf16`      | Controls the numerical precision during neural network inference. bf16 is supported by GPU accelerators A100, H100 and higher, while others will require fp32 inference. (bf16/fp32)  |
| `--infer_times`         |   `4`         | The number of independent seeds used to generate structure predictions using the HelixFold3 model.  |

> You can override any of these parameters via the command line or a params file.