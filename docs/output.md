# nf-core/proteinfold: Output

## Introduction

This document describes the user-facing output produced by the pipeline.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and predicts protein structures using the following methods:

- [AlphaFold2](https://github.com/google-deepmind/alphafold)
- [AlphaFold3](https://github.com/google-deepmind/alphafold3)
- [Boltz](https://github.com/jwohlwend/boltz)
- [ColabFold](https://github.com/sokrypton/ColabFold)
- [ESMFold](https://github.com/facebookresearch/esm)
- [RoseTTAFold2NA](https://github.com/uw-ipd/RoseTTAFold2NA)
- [RoseTTAFold-All-Atom](https://github.com/baker-laboratory/RoseTTAFold-All-Atom/)
- [HelixFold3](https://github.com/PaddlePaddle/PaddleHelix/tree/dev/apps/protein_folding/helixfold3)

See main [README.md](https://github.com/nf-core/proteinfold/blob/master/README.md) for a condensed overview of the steps in the pipeline, and the bioinformatics tools used at each step.

The directories listed below will be created in the output directory after the pipeline has finished. All paths are relative to the top-level results directory.

Exact subdirectories depend on the selected mode(s). In a multi-mode run (for example `alphafold2,boltz,rosettafold_all_atom`) you will typically see top-level directories such as `alphafold2/`, `boltz/`, `rosettafold_all_atom/`, `multiqc/`, `reports/`, `compare/`, and `pipeline_info/`.

### Prediction outputs (all modes)

User-facing outputs are largely consistent across modes.

<details markdown="1">
<summary>Common output patterns</summary>

- `<MODE>/top_ranked_structures/<SEQUENCE NAME>.{pdb,cif}` (format depends on the selected mode)
- `<MODE>/<SEQUENCE NAME>/<SEQUENCE NAME>_plddt.tsv`
- `<MODE>/<SEQUENCE NAME>/paes/<SEQUENCE NAME>_<RANK>_pae.tsv` (when available)
- `<MODE>/<SEQUENCE NAME>/<SEQUENCE NAME>_<MODE>_msa.tsv` (mode-specific MSA summary)
- `<MODE>/<SEQUENCE NAME>/<SEQUENCE NAME>_{ptm,iptm,ipsae}.tsv` and chainwise summaries (where applicable)

</details>

### pLDDT (`{meta.id}_plddt.tsv`)

Confidence values per residue, rounded to 2 decimal places. Each ranked result gets its own column (for all-atom modules, atomic token confidences are processed to a naive mean value across the residue).

```
Positions	rank_0	rank_1	rank_2	rank_3	rank_4
0	41.37	44.82	46.15	43.98	45.26
1	55.24	53.67	57.91	54.88	56.03
2	62.89	60.44	64.13	61.95	63.27
3	71.46	69.22	73.85	70.14	72.31
4	79.33	77.48	81.26	78.92	80.05
5	84.57	82.63	86.49	83.74	85.12
6	88.91	86.77	90.35	87.68	89.42
7	92.14	90.05	93.58	91.33	92.76
8	94.63	92.84	95.77	93.95	94.88
9	96.27	94.51	97.06	95.22	96.41
10	97.34	95.62	97.88	96.03	97.19
11	96.85	95.07	97.42	95.66	96.73
12	95.92	94.11	96.58	94.82	95.67
13	94.38	92.74	95.21	93.56	94.19
14	92.77	91.02	93.68	91.84	92.55
15	90.64	88.93	91.72	89.51	90.38
16	87.26	85.41	88.37	86.02	87.09
17	82.93	81.17	84.06	81.88	82.74
18	76.58	74.92	77.85	75.44	76.31
19	68.44	66.83	69.71	67.12	68.20
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

(i)pTM scores, rounded to 3 decimal places. Two tab-separated columns: rank index (integer) and score value. Rows are sorted by rank index.

```
rank_0	0.617
rank_1	0.616
rank_2	0.610
rank_3	0.606
rank_4	0.606
```

### chain-wise (i)pTM (`{meta.id}_chainwise_[i]ptm.tsv`)

Chain-wise iPTM values, rounded to 4 decimal places, with chain-pair lettering as the row (`X:Y`) and rank number as the column. Where available, self-scores are included as `X:X`.

```
0	1	2
A:B	0.2880	0.2750	0.2900
B:A	0.2904	0.2801	0.2915
```

In the HTML reports, chainwise iPTM and ipSAE are displayed as chain-by-chain matrices for each ranked model. Modes that do not emit these metrics omit the corresponding report sections.

**IpTM Derivation and Attribution**

- **Derived vs native values:** iPTM values may come either from the prediction program itself (when the program emits an `iptm` or chain-pair matrix) or be derived after-the-fact by running the `ipsae.py` utility included in this pipeline. Derived values are generated from the model's PAE/PAE-like output and are not guaranteed to be numerically identical to program-native iPTM values; they follow the ipSAE/ipTM algorithm used by the IPSAE project and are intended to provide a consistent interface-derived score when a native value is not available.
- **Default cutoffs used when deriving:** when `extract_metrics.py` derives iPTM/ipSAE it invokes `ipsae.py` with a PAE cutoff of `10` and a distance cutoff of `15` (these are currently hard-coded in the extraction step). If you require different thresholds, compute iPTM/ipSAE externally or update the extraction call accordingly.
- **Third-party attribution:** the `ipsae.py` utility bundled in `bin/` is derived from the IPSAE project by the Dunbrack Lab (https://github.com/DunbrackLab/IPSAE/). The original script includes an MIT-style header; keep that header intact if the file is redistributed. Please consult the IPSAE repository for full details and citation information.

### PAE (`{meta.id}_{rank_number}_pae.tsv`)

Predicted alignment error of residues `j` aligned by residue `i`, rounded to 4 decimal places.
The row number gives you the index of residue `i` and the column value within the row gives the index of residue `j` for the 2D PAE matrix.

Each model prediction generates a separate file containing the rank number. Rank numbering follows the native convention of the underlying tool, so top-ranked models may appear as either `_0_pae.tsv` or `_1_pae.tsv` depending on the mode. Additional ranked results are stored within the `paes/` folder.

```
0.2601	0.9304	2.4003	2.5593	2.8825	3.6264	5.1762	5.4703	5.8908	6.8693	6.4607	7.2999	8.2147	7.2408	7.2605	6.1839	6.4634	6.3633	5.1218	6.8676
0.3936	0.2597	0.3651	0.7886	0.8606	0.7701	1.0634	1.5954	1.9888	1.9016	1.4267	1.7906	2.4564	2.4413	2.6282	2.0645	1.7964	1.2656	1.2455	2.1183
0.6763	0.2815	0.2591	0.2675	0.3687	0.3773	0.4059	0.5230	0.7725	0.9013	0.7630	1.0684	1.2106	1.2841	1.4175	1.2333	1.0690	0.7934	0.8171	1.4173
0.7324	0.4105	0.2659	0.2592	0.2790	0.3887	0.4264	0.4285	0.6522	0.8780	0.7665	1.0509	1.2620	1.2812	1.5058	1.2865	1.1525	0.8162	0.9117	1.5089
0.8014	0.4842	0.3393	0.2663	0.2593	0.2707	0.3640	0.4068	0.4551	0.7048	0.6402	1.0301	1.1207	1.0363	1.2828	1.0275	1.0658	0.8291	0.9196	1.6125
0.9024	0.5183	0.3556	0.3052	0.2630	0.2590	0.2618	0.3299	0.4175	0.5138	0.4431	0.7571	0.9117	0.8969	1.2054	0.8778	0.8008	0.6304	0.7926	1.4000
```

#### Example report plots

The report exports include key visualisations such as sequence coverage, predicted Local Distance Difference Test (pLDDT), and Predicted Aligned Error (PAE).

##### Sequence coverage

![Sequence coverage](images/sequence_coverage_proteinfold-v2.png?raw=true "Example sequence coverage plot")

##### predicted Local Distance Difference Test (pLDDT)

![pLDDT](images/plddt_proteinfold-v2.png?raw=true "Example pLDDT plot")

##### Predicted Aligned Error (PAE)

![PAE](images/pae_proteinfold-v2.png?raw=true "Example PAE plot")

### Per-mode reports and comparisons

<details markdown="1">
<summary>Output files</summary>

- `reports/`
  - `<SEQUENCE NAME>_<MODE>_report.html` (single-mode report per sequence/mode)
- `compare/`
  - `<SEQUENCE NAME>_comparison_report.html` (present when running multiple modes)

</details>

### Foldseek structural similarity search

If Foldseek is enabled (`--skip_foldseek false`), results are written to:

<details markdown="1">
<summary>Output files</summary>

- `foldseek_easysearch/`
  - `<SEQUENCE NAME>_<MODE>_foldseek.html` (default output format)
  - `<SEQUENCE NAME>.m8` (tabular output when `--foldseek_easysearch_arg` does not include `--format-mode 3`)

</details>

Foldseek runs on top-ranked structures from each selected mode and sequence. By default, the pipeline uses `--format-mode 3` and publishes HTML reports.

### MultiQC report

<details markdown="1">
<summary>Output files</summary>

- `multiqc`
  - `*_multiqc_report.html`: Standalone HTML report(s) that can be viewed in your web browser.
  - `*_multiqc_report_data/`: Parsed report data for each corresponding MultiQC report.

</details>

[MultiQC](https://multiqc.info/docs/) is a visualisation tool that generates HTML report(s) summarising samples in your project. Most QC results are visualised in the report and further statistics are available within each corresponding `*_multiqc_report_data/` directory.

Results generated by MultiQC collate QC metrics from the selected structure-prediction mode(s), and the software versions for traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.

### Additional intermediate outputs

Depending on the selected mode(s) and options, additional top-level directories may be present, for example:

- `fasta2yaml/` (for YAML conversion inputs/outputs)
- `mmseqs/results/` (for MMseqs2 outputs such as `.a3m` files)
- `split/output_msa/` (for split-MSA intermediate CSV outputs)

### `--save_intermediates`

If `--save_intermediates` is enabled, extra raw intermediate files are published in mode-specific `raw/` directories.

Examples include:

- `alphafold2/<MODE>/<SEQUENCE NAME>/raw/`
- `colabfold/<SEQUENCE NAME>/raw/`
- `boltz/<SEQUENCE NAME>/boltz_results_<SEQUENCE NAME>/`
- `rosettafold_all_atom/<SEQUENCE NAME>/raw/`
- `alphafold3/<SEQUENCE NAME>/raw/`
- `helixfold3/<SEQUENCE NAME>/raw/`
- `rosettafold2na/<SEQUENCE NAME>/raw/`

These raw outputs are intended for advanced debugging, reproducibility and method-specific downstream analyses. For detailed, canonical tool-specific native output specifications, see:

- [AlphaFold2](https://github.com/google-deepmind/alphafold?tab=readme-ov-file#alphafold-output)
- [AlphaFold3](https://github.com/google-deepmind/alphafold3/blob/main/docs/output.md)
- [Boltz](https://github.com/jwohlwend/boltz/blob/main/docs/prediction.md#output)
- [ColabFold](https://www.ebi.ac.uk/training/online/courses/alphafold/advanced-modeling-and-applications-of-predicted-protein-structures/customising-alphafold-structure-predictions/outputs-from-colabfold/)
- [ESMFold](https://github.com/facebookresearch/esm)
- [RosettaFold2NA](https://github.com/uw-ipd/RoseTTAFold2NA?tab=readme-ov-file#expected-outputs)
- [RoseTTAFold-All-Atom](https://github.com/baker-laboratory/RoseTTAFold-All-Atom/?tab=readme-ov-file#understanding-model-outputs)
- [HelixFold3](https://github.com/PaddlePaddle/PaddleHelix/tree/dev/apps/protein_folding/helixfold3#-understanding-model-output)
