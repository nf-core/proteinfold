# nf-core/proteinfold: Output

## Introduction

This document describes the output produced by the pipeline.

Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and predicts protein structures using the following methods:

- [AlphaFold2](https://github.com/deepmind/alphafold)
- [ColabFold](https://github.com/sokrypton/ColabFold) - MMseqs2 (API server or local search) followed by ColabFold
- [ESMFold](https://github.com/facebookresearch/esm)

See main [README.md](https://github.com/nf-core/proteinfold/blob/master/README.md) for a condensed overview of the steps in the pipeline, and the bioinformatics tools used at each step.

The directories listed below will be created in the output directory after the pipeline has finished. All paths are relative to the top-level results directory.

### AlphaFold2

<details markdown="1">
<summary>Output files</summary>

- `AlphaFold2/`
  - `<SEQUENCE NAME>/` that contains the computed MSAs, unrelaxed structures, relaxed structures, ranked structures, raw model outputs, prediction metadata, and section timings
  - `<SEQUENCE NAME>.alphafold.pdb` that is the structure with the highest pLDDT score (ranked first)
  - `<SEQUENCE NAME>_plddt_mqc.tsv` that presents the pLDDT scores per residue for each of the 5 predicted models
- `DBs/` that contains symbolic links to the downloaded database and parameter files

</details>

Below you can find an indicative example of the TSV file with the pLDDT scores per residue for each of the 5 predicted models produced by AlphaFold2, which is included in the MultiQC report:

| Positions | rank_0 | rank_1 | rank_2 | rank_3 | rank_4 |
| --------- | ------ | ------ | ------ | ------ | ------ |
| 1         | 66.17  | 60.61  | 60.32  | 64.20  | 65.31  |
| 2         | 78.01  | 74.20  | 73.11  | 77.36  | 78.46  |
| 3         | 82.16  | 78.16  | 76.70  | 80.20  | 80.68  |
| 4         | 86.03  | 82.78  | 81.88  | 82.19  | 83.93  |
| 5         | 88.08  | 84.38  | 84.73  | 85.58  | 87.70  |
| 6         | 89.37  | 86.06  | 86.31  | 86.84  | 88.52  |
| 7         | 91.27  | 88.27  | 88.09  | 87.01  | 88.67  |
| 8         | 91.28  | 89.42  | 90.17  | 87.47  | 90.07  |
| 9         | 93.10  | 90.09  | 92.86  | 90.70  | 93.41  |
| 10        | 93.23  | 91.42  | 93.07  | 90.13  | 92.91  |
| 11        | 94.12  | 92.44  | 93.00  | 89.90  | 92.97  |
| 12        | 95.15  | 93.63  | 94.25  | 92.66  | 94.38  |
| 13        | 95.09  | 93.75  | 94.36  | 92.54  | 94.95  |
| 14        | 94.08  | 92.72  | 93.43  | 90.31  | 93.63  |
| 15        | 94.34  | 93.77  | 93.31  | 91.72  | 93.57  |
| 16        | 95.56  | 94.62  | 94.46  | 93.55  | 95.20  |
| 17        | 95.54  | 94.75  | 94.65  | 93.61  | 95.37  |
| 18        | 93.91  | 93.89  | 93.30  | 91.33  | 92.95  |
| 19        | 95.48  | 95.78  | 94.48  | 93.95  | 95.05  |
| 20        | 95.96  | 95.46  | 95.14  | 94.01  | 95.83  |
| 21        | 94.06  | 94.06  | 93.13  | 91.69  | 93.54  |
| 22        | 92.98  | 93.28  | 91.14  | 88.80  | 91.25  |
| 23        | 95.28  | 95.13  | 93.39  | 91.48  | 93.56  |
| 24        | 93.41  | 93.38  | 92.32  | 89.85  | 92.40  |
| 25        | 90.88  | 91.40  | 88.60  | 85.67  | 87.65  |
| 26        | 89.30  | 88.90  | 84.58  | 83.11  | 84.52  |
| 27        | 91.96  | 90.95  | 89.04  | 86.42  | 87.77  |
| 28        | 91.20  | 90.68  | 88.71  | 86.43  | 87.62  |
| 29        | 88.01  | 87.53  | 85.83  | 83.11  | 84.95  |
| 30        | 81.29  | 83.72  | 77.75  | 75.76  | 74.84  |
| 31        | 87.14  | 86.92  | 82.10  | 82.32  | 78.74  |
| 32        | 92.34  | 90.13  | 89.04  | 88.31  | 86.49  |
| 33        | 91.70  | 88.94  | 85.52  | 85.94  | 81.75  |
| 34        | 90.11  | 88.23  | 84.33  | 85.47  | 80.01  |
| 35        | 93.35  | 91.49  | 90.60  | 89.40  | 87.10  |
| 36        | 94.15  | 92.47  | 90.17  | 90.48  | 86.77  |
| 37        | 93.40  | 92.01  | 86.38  | 87.84  | 80.11  |
| 38        | 92.79  | 89.97  | 89.31  | 88.55  | 85.15  |
| 39        | 94.66  | 91.29  | 92.74  | 90.67  | 90.30  |
| 40        | 95.98  | 93.58  | 94.30  | 91.69  | 90.73  |
| 41        | 94.94  | 92.57  | 88.31  | 88.40  | 80.33  |
| 42        | 92.89  | 91.03  | 84.03  | 85.31  | 74.66  |
| 43        | 94.54  | 93.44  | 86.50  | 84.91  | 76.68  |
| 44        | 96.93  | 95.23  | 92.42  | 91.98  | 86.11  |
| 45        | 94.40  | 92.27  | 87.40  | 89.02  | 79.44  |
| 46        | 91.74  | 90.94  | 81.35  | 84.88  | 74.93  |
| 47        | 96.19  | 94.46  | 90.51  | 89.82  | 84.51  |
| 48        | 94.84  | 93.04  | 91.02  | 91.57  | 87.72  |
| 49        | 91.23  | 89.34  | 86.10  | 87.63  | 82.12  |
| 50        | 91.64  | 89.58  | 84.93  | 85.88  | 79.38  |

### ColabFold

<details markdown="1">
<summary>Output files</summary>

- `colabfold/webserver/` or `colabfold/local/` based on the selected mode that contains the computed MSAs, unrelaxed structures, relaxed structures, ranked structures, raw model outputs and scores, prediction metadata, logs and section timings
- `DBs/` that contains symbolic links to the downloaded database and parameter files

</details>

Below you can find some indicative examples of the output images produced by ColabFold, which are included in the MultiQC report:

#### Sequence coverage

![Alt text](../docs/images/T1024_LmrP____408_residues__coverage_mqc.png?raw=true "T1024_coverage")

#### predicted Local Distance Difference Test (pLDDT)

![Alt text](../docs/images/T1024_LmrP____408_residues__plddt_mqc.png?raw=true "T1024_coverage")

#### Predicted Aligned Error (PAE)

![Alt text](../docs/images/T1024_LmrP____408_residues__PAE_mqc.png?raw=true "T1024_coverage")

### ESMFold

<details markdown="1">
<summary>Output files</summary>

- `esmfold/`
  - `<SEQUENCE NAME>.pdb` that is the structure with the highest pLDDT score (ranked first)
  - `<SEQUENCE NAME>_plddt_mqc.tsv` that presents the pLDDT scores per residue for each of the 5 predicted models
- `DBs/` that contains symbolic links to the downloaded database and parameter files

</details>

Below you can find an indicative example of the TSV file with the pLDDT scores per atom for predicted model produced by ESMFold, which is included in the MultiQC report:

| Atom_serial_number | Atom_name | Residue_name | Residue_sequence_number | pLDDT |
| ------------------ | --------- | ------------ | ----------------------- | ----- |
| 1                  | N         | VAL          | 1                       | 44.77 |
| 2                  | CA        | VAL          | 1                       | 47.23 |
| 3                  | C         | VAL          | 1                       | 46.66 |
| 4                  | CB        | VAL          | 1                       | 41.88 |
| 5                  | O         | VAL          | 1                       | 45.75 |
| 6                  | CG1       | VAL          | 1                       | 39.15 |
| 7                  | CG2       | VAL          | 1                       | 39.59 |
| 8                  | N         | THR          | 2                       | 49.89 |
| 9                  | CA        | THR          | 2                       | 51.41 |
| 10                 | C         | THR          | 2                       | 50.21 |
| 11                 | CB        | THR          | 2                       | 43.84 |
| 12                 | O         | THR          | 2                       | 47.36 |
| 13                 | CG2       | THR          | 2                       | 35.32 |
| 14                 | OG1       | THR          | 2                       | 40.12 |
| 15                 | N         | VAL          | 3                       | 51.40 |
| 16                 | CA        | VAL          | 3                       | 54.38 |
| 17                 | C         | VAL          | 3                       | 52.10 |
| 18                 | CB        | VAL          | 3                       | 48.50 |
| 19                 | O         | VAL          | 3                       | 52.58 |
| 20                 | CG1       | VAL          | 3                       | 38.75 |
| 21                 | CG2       | VAL          | 3                       | 39.26 |
| 22                 | N         | ASP          | 4                       | 52.00 |
| 23                 | CA        | ASP          | 4                       | 53.92 |
| 24                 | C         | ASP          | 4                       | 52.33 |
| 25                 | CB        | ASP          | 4                       | 46.82 |
| 26                 | O         | ASP          | 4                       | 51.28 |
| 27                 | CG        | ASP          | 4                       | 42.89 |
| 28                 | OD1       | ASP          | 4                       | 45.89 |
| 29                 | OD2       | ASP          | 4                       | 53.61 |
| 30                 | N         | ASP          | 5                       | 56.10 |
| 31                 | CA        | ASP          | 5                       | 56.97 |
| 32                 | C         | ASP          | 5                       | 55.75 |
| 33                 | CB        | ASP          | 5                       | 50.34 |
| 34                 | O         | ASP          | 5                       | 54.18 |
| 35                 | CG        | ASP          | 5                       | 45.82 |
| 36                 | OD1       | ASP          | 5                       | 50.03 |
| 37                 | OD2       | ASP          | 5                       | 58.01 |
| 38                 | N         | LEU          | 6                       | 56.50 |
| 39                 | CA        | LEU          | 6                       | 58.34 |
| 40                 | C         | LEU          | 6                       | 55.81 |
| 41                 | CB        | LEU          | 6                       | 52.46 |
| 42                 | O         | LEU          | 6                       | 54.42 |
| 43                 | CG        | LEU          | 6                       | 49.17 |
| 44                 | CD1       | LEU          | 6                       | 44.31 |
| 45                 | CD2       | LEU          | 6                       | 47.07 |
| 46                 | N         | VAL          | 7                       | 57.23 |
| 47                 | CA        | VAL          | 7                       | 57.68 |
| 48                 | C         | VAL          | 7                       | 57.39 |
| 49                 | CB        | VAL          | 7                       | 52.74 |
| 50                 | O         | VAL          | 7                       | 56.46 |

### MultiQC report

<details markdown="1">
<summary>Output files</summary>

- `multiqc`
  - `<MODE>_multiqc_report.html`: A standalone HTML file that can be viewed in your web browser.
  - `<MODE>_multiqc_data/`: Directory containing parsed statistics from the different tools used in the pipeline.
  - `<MODE>_multiqc_plots/`: Directory containing static images from the report in various formats.

</details>

[MultiQC](https://multiqc.info/docs/) is a visualisation tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available within the report data directory.

Results generated by MultiQC collate pipeline QC from AlphaFold2 or ColabFold.

The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see http://multiqc.info.

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
