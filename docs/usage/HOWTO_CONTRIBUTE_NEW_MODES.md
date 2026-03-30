---
title: Contributing new modes
subtitle: Adding structure prediction modes to nf-core/proteinfold
weight: 100
---

# Adding structure prediction modes to nf-core/proteinfold

This section provides guidance on adding new structure prediction modes, implemented via the `--mode` option, to nf-core/proteinfold.

## Contributing

One of the great advantages of an `nf-core` pipeline is that the community can extend workflows to add new functionalities. In nf-core/proteinfold, this allows adding new protein structure prediction modules as they are released, while still leveraging the existing workflow infrastructure and reporting.

Please consider writing some code to become a [nf-core contributor](https://nf-co.re/contributors) and expand the pipeline! Reach out to a maintainer of contributor for guidance :

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
