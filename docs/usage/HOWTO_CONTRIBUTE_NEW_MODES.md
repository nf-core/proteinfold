# Adding structure prediction modes to nf-core/proteinfold

This section provides guidance on adding new structure prediction modes, implemented via the `--mode` option, to nf-core/proteinfold.

## Contributing

One of the great advantages of an `nf-core` pipeline is that the community can extend workflows to add new functionalities. In nf-core/proteinfold, this allows adding new protein structure prediction modules as they are released, while still leveraging the existing workflow infrastructure and reporting.

Please consider writing some code to become a [nf-core contributor](https://nf-co.re/contributors) and expand the pipeline! Reach out to a maintainer of contributor for guidance :)

We are all contactable at the [#proteinfold_dev](https://nfcore.slack.com/archives/C08THK11CHX) nf-core Slack channel. That's the best place for person-to-person discussions over new additions to implement into the pipeline.

## Locating pipeline sections

- `main.nf`: This kicks off each `--mode`'s workflow once the databases have been prepared on the deployment infrastructure. Relevant parameters are passed from `params.[mode_name]` (largely populated from global `nextflow.config` `params` which inherits `dbs.config` database locations) through to the `[MODE_NAME]()` workflow. The channels returned contain the relevant `report_input` metrics, the `top_rank_model` (_i.e._ the best structure from all inference runs), and standard software versioning info.
- `subworkflows`: largely used for mode-specific smaller set-up worklows, except for the `post_processing` subworkflow which will be detailed later.
- `workflows/[mode_name].nf`: the `--mode`'s workflow handles input channels of relevant databases, passes them to the local module that does the prediction work (`RUN_[MODE_NAME]()`) and maps the output from the underlying structure prediction to emitted channels ingested by the reporting modules.
- `modules/local/run_[MODE_NAME]`: this is where the bulk of the compute work is done. Each underlying structure prediction module is bundled with its own Dockerfile to setup the software in a container, and a `/modules/local/run_[MODE_NAME]/main.nf` to execute the container from nextflow.
  - input:
    - `meta` contains the metadata info of this sub-job, including the `id` column from the `samplesheet.csv` accessed by `{meta.id}`.
    - `path(fasta)` (or more flexible yaml or json) locates the biomolecular input sequence file, where `fasta.baseName` gives the underlying input file name (not the `id` label).
    - `path(features)` is used to pass through multiple sequence alignment (MSA) data, in line with AlphaFold2's [features.pkl](https://github.com/google-deepmind/alphafold?tab=readme-ov-file#alphafold-output) file.
    - Other `path()`s largely locate the core [AlphaFold sequence databases](https://github.com/google-deepmind/alphafold?tab=readme-ov-file#genetic-databases) (or module specific variants thereof).
  - output:
    - Outputs are structured as a bundled `tuple` of two objects, the first is always `meta` containing the metadata labels, and then `path()` to various output data files useful to the end-user. The prediction module is called in a way that return files to the process's current directory (`.`).
  - `"""script block"""`:
    - `program`: the script block calls the program from the Nextflow shell with the programs typical `--flags`, in whatever form (`binary` or `script.py`) the program is distributed from its codebase repository.
    - `extract_metrics.py`: accesses the canonical data output formats from the structure prediction program and returns a core set of plain text `.tsv` metric files.
- `bin/extract_metrics.py`: a globally accessible program to go from serialised data into `.tsv` plaintext. It currently applies format specific extraction logic for `.pkl`, `.json` and `.npz` files. However, as the community adds more `--mode`s to the pipeline, different programs could use the same compressed output format. In which case `extract_metrics.py` should be refactored to match based on the passing the `--mode` to `extract_metrics.py`.
- `subworkflows/local/post_processing.nf`: the `POST_PROCESSING{}` process sits after all possible `[MODE_NAME]()` workflows in the `main.nf`. It passes along visualisation options, metrics data files, and report templates (`single` or `comparison`). Those reports are created with the `GENERATE_REPORT()` or `COMPARE_STRUCTURES()` `/module/local/` modules, respectively.
- `bin/generate_[comparison]_report.py` takes the HTML templates at `assets/[report|comparison]_template.html` and populates them with plots created inside these python scripts.

## Process labelling

At the top of a module's `RUN_[MODE_NAME]`{} process, there are a series of labels that allow the `nextflow.config` to pass the job to the appropriate resources on the compute cluster. `label 'process_gpu'` is very useful to specify the AI inference stages requiring GPU-intensive computation. Other processes can use default labels that request CPU resources and, once finished, will naturally cascade onto GPU-enabled steps due to Nextflow's dataflow paradigm.

## Processable structure prediction metrics

Metrics from AlphaFold-inspired protein structure prediction programs are structured in two ways: tabular or as a matrix (PAE values)

When contributing a new mode to `proteinfold`, functionality should be added to `extract_metrics.py` to access the canonical ouput files of the new program, and extract data into compliant `.tsv` files that can be easily processed by downstream plotting and MultiQC functions.

> [!WARNING]
> Metrics files are **0 indexed**.

### pLDDT (`{meta.id}_plddt.tsv`)

Confidence values per residue, rounded to 2 decimal places. Each ranked result gets its own column (for all-atom modules, atomic token confidences are processed to a naive mean value across the residue).

```
Positions	rank_0	rank_1	rank_2	rank_3	rank_4
0	83.58	85.27	88.41	86.22	84.91
1	97.99	97.81	97.39	97.49	97.32
2	98.22	98.42	98.16	97.88	97.81
3	98.06	98.15	97.94	97.56	97.4
4	98.67	98.56	98.3	98.38	98.29
5	98.81	98.77	98.62	98.61	98.54
6	98.79	98.74	98.57	98.59	98.52
...
```

### MSA (`{meta.id}_{meta.mode}_msa.tsv`)

The amino acid characters are converted to integers `0-19`, unknown as 20, **integer `21`** represents the gap character.

```
19	5	5	4	10	16	15	3	8	15	13	16	12	9	17	16	9	4	8	11	0	7	7	8	11	0	19	8	8	5	3
19	5	5	4	10	16	15	3	8	15	13	16	12	9	17	16	9	4	8	11	0	7	7	8	11	0	6	8	8	5	13
19	5	5	4	10	5	15	13	14	0	14	16	12	9	17	16	9	4	14	11	0	7	5	8	15	4	5	8	3	5	21
19	5	5	4	10	16	15	3	8	15	13	16	12	9	17	16	9	4	8	11	0	7	7	8	11	0	19	8	8	5	21
19	5	5	4	10	16	15	3	8	15	13	16	12	9	17	16	9	4	8	11	0	7	7	8	11	0	19	8	8	5	13
19	5	5	4	10	16	15	3	8	15	13	16	12	9	7	16	9	4	8	11	0	7	7	8	11	0	6	8	8	5	13
```

This allows easy sequence indentity calculation when processing as a `numpy` array.

### (i)pTM (`{meta.id}_[i]ptm.tsv`)

(i)pTM scores, rounded to 3 decimal places, listed by the rank number (currently unsorted).

```
17  0.552
22  0.529
21  0.532
20  0.541
23  0.523
3 0.606
2 0.610
4 0.606
1 0.616
0 0.617
12  0.580
9 0.588
13  0.580
11  0.583
14  0.570
15  0.565
24  0.517
16  0.560
18  0.550
19  0.550
10  0.588
5 0.600
6 0.597
7 0.596
8 0.595
```

### chain-wise (i)pTM (`{meta.id}_chainwise_[i]ptm.tsv`)

(Symmetrical) ipTM scores, rounded to 4 decimal places, with chain pair lettering as the row (`X:Y`), and the rank number as the column. A pTM value is a chain's own predicted Template Modelling score so lettering will be `X:X`.

```
0	1	2
A:B	0.2880	0.2750	0.2900
B:A	0.2904	0.2801	0.2915
```

### PAE (`{meta.id}_{rank_number}_pae.tsv`)

Predicted alignment error from residue `i` aligned to residue `j`, rounded to 4 decimal places.
The row number gives you the index of residue `i` and the column value within the row gives the index of residue `j` for the 2D PAE matrix.

Each model prediction generates a separate file containing the rank number. The `_0_pae.tsv` file corresponds to the top ranked model, other ranked results are stored within the `./pae` folder.

```
0.2500	1.5710	3.9037	6.2177	8.4471	11.4583	12.9679	15.1237	18.0263	18.3868	18.9381	20.5747	19.3314	20.1825	21.6145	23.2190
2.2177	0.2500	1.5559	4.0327	6.3151	7.6372	10.1969	11.3626	14.9366	16.1303	17.9119	19.1877	21.2715	20.9531	20.1760	19.4087
3.4270	1.5284	0.2500	2.1333	3.5351	5.1049	6.6521	8.2317	12.1379	13.7185	14.9523	16.6154	19.6988	21.7614	18.6592	17.9619
6.1051	5.4206	2.5987	0.2500	2.0724	5.1454	6.7492	9.5538	9.6285	12.3868	13.8527	16.3586	17.2605	20.6381	19.9987	19.3295
7.3512	6.4947	5.5435	2.6740	0.2500	1.7561	4.9041	6.3923	8.9735	8.9272	12.3419	14.6005	15.9820	17.6358	20.5190	19.1028
7.4734	7.0899	5.8128	5.7512	2.0439	0.2500	1.8352	5.1064	6.4225	9.2098	10.5136	12.9404	14.3152	16.8122	18.6336	17.7382
```
