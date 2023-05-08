# nf-core/proteinfold: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0 - White Silver Reebok

Initial release of nf-core/proteinfold, created with the [nf-core](https://nf-co.re/) template.

### Enhancements & fixes

- Updated pipeline template to [nf-core/tools 2.7.2](https://github.com/nf-core/tools/releases/tag/2.7.2)

## 1.1.0

### Enhancements & fixes

- [#80] Add `accelerator` directive to GPU processes when `params.use_gpu` is true.

- [#81] Support multiline fasta for colabfold multimer predictions

- [#89] Fix issue with excessive symlinking in the pdb_mmcif database

- [#90] Update pipeline template to [nf-core/tools 2.8](https://github.com/nf-core/tools/releases/tag/2.8)

- [#91] Update ColabFold version to 1.5.2 and AlphaFold version to 2.3.2

- [#92] Add ESMFold workflow to the pipeline
-  Update metro map to include ESMFold flow.
