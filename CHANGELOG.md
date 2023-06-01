# nf-core/proteinfold: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.0dev - [date]

### Enhancements & fixes

- [#80](https://github.com/nf-core/proteinfold/pull/80) Add `accelerator` directive to GPU processes when `params.use_gpu` is true.

- [#81](https://github.com/nf-core/proteinfold/pull/81) Support multiline fasta for colabfold multimer predictions.

- [#89](https://github.com/nf-core/proteinfold/pull/89) Fix issue with excessive symlinking in the pdb_mmcif database.

- [#90](https://github.com/nf-core/proteinfold/pull/90) Update pipeline template to [nf-core/tools 2.8](https://github.com/nf-core/tools/releases/tag/2.8).

- [#91](https://github.com/nf-core/proteinfold/pull/91) Update ColabFold version to 1.5.2 and AlphaFold version to 2.3.2

- [#92](https://github.com/nf-core/proteinfold/pull/92) Add ESMFold workflow to the pipeline.

- Update metro map to include ESMFold workflow.

- Update modules to remove quay from container url.

- [nf-core/tools#2286](https://github.com/nf-core/tools/issues/2286) Set default container registry outside profile scope.

- [#97](https://github.com/nf-core/proteinfold/pull/97) Fix issue with uniref30 missing path when using the full BFD database in AlphaFold

- [#100](https://github.com/nf-core/proteinfold/pull/100) Update containers for AlphaFold2 and ColabFold local modules

- [#105](https://github.com/nf-core/proteinfold/pull/105) Update COLABFOLD_BATCH docker container, metro map figure and nextflow schema description

## 1.0.0 - White Silver Reebok

Initial release of nf-core/proteinfold, created with the [nf-core](https://nf-co.re/) template.

### Enhancements & fixes

- Updated pipeline template to [nf-core/tools 2.7.2](https://github.com/nf-core/tools/releases/tag/2.7.2)
