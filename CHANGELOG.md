# nf-core/proteinfold: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.2.0dev - [date]

### Enhancements & fixes

- [[#177](https://github.com/nf-core/proteinfold/issues/177)] - Fix typo in some instances of model preset `alphafold2_ptm`.
- [[PR #178](https://github.com/nf-core/proteinfold/pull/178)] - Enable running multiple modes in parallel.
- [[#179](https://github.com/nf-core/proteinfold/issues/179)] - Produce an interactive html report for the predicted structures.
- [[#180](https://github.com/nf-core/proteinfold/issues/180)] - Implement Foldseek.
- [[#188](https://github.com/nf-core/proteinfold/issues/188)] - Fix colabfold image to run in gpus.
- [[PR ##205](https://github.com/nf-core/proteinfold/pull/205)] - Change input schema from `sequence,fasta` to `id,fasta`.
- [[PR #210](https://github.com/nf-core/proteinfold/pull/210)] - Moving post-processing logic to a subworkflow, change wave images pointing to oras to point to https and refactor module to match nf-core folder structure.
- [[#214](https://github.com/nf-core/proteinfold/issues/214)] - Fix colabfold image to run in cpus after [#188](https://github.com/nf-core/proteinfold/issues/188) fix.
- [[PR ##220](https://github.com/nf-core/proteinfold/pull/220)] - Add RoseTTAFold-All-Atom module.
- [[PR ##223](https://github.com/nf-core/proteinfold/pull/223)] - Add HelixFold3 module.
- [[#235](https://github.com/nf-core/proteinfold/issues/235)] - Update samplesheet to new version (switch from `sequence` column to `id`).
- [[#239](https://github.com/nf-core/proteinfold/issues/239)] - Update alphafold2 standard mode Dockerfile.
- [[#240](https://github.com/nf-core/proteinfold/issues/240)] - Separate download and input of pdb `mmcif` files and `obsolete` database.
- [[#229](https://github.com/nf-core/proteinfold/issues/229)] - Add Boltz pipeline [PR #227](https://github.com/nf-core/proteinfold/pull/227).
- [[PR #249](https://github.com/nf-core/proteinfold/pull/249)] - Update pipeline template to [nf-core/tools 3.2.0](https://github.com/nf-core/tools/releases/tag/3.2.0).
- [[PR #271](https://github.com/nf-core/proteinfold/pull/271)] - Update RFAA and HF3 dockerfiles for quicker building and reduction in image size.
- [[PR #274](https://github.com/nf-core/proteinfold/pull/274)] - Simplify run_helixfold3 module and move arguments to `modules.config`.
- [[#276](https://github.com/nf-core/proteinfold/issues/276)] - Update helixfold3 dockerfile to make it compatible with H100 gpus.
- [[#259](https://github.com/nf-core/proteinfold/issues/259)] - Fix `esmfold` docker image to make it compatible with hopper GPU architecture.
- [[#281](https://github.com/nf-core/proteinfold/issues/281)] - Fix how argument `--nv` is passed to apptainer and singularity in the config.
- [[PR #283](https://github.com/nf-core/proteinfold/pull/283)] - Fixes to meet language server requirements and update link of the helixfold3 image.
- [[PR #287](https://github.com/nf-core/proteinfold/pull/287)] - Fixes symlinking of every mmcif file causing excess I/O.
- [[#293](https://github.com/nf-core/proteinfold/issues/293)] - Add back `alphafold2_model_preset` input to the call to `run_alphafold2_pred`.
- [[PR #294](https://github.com/nf-core/proteinfold/pull/294)] - Temporary downgrade of schema for passing CI tests with Nextflow edge version.
- [[#272](https://github.com/nf-core/proteinfold/issues/272)] - Colouring scheme conforming to AlphaFold2 confidence bands in html report.
- [[PR #297](https://github.com/nf-core/proteinfold/pull/297)] - Update pipeline template to [nf-core/tools 3.2.1](https://github.com/nf-core/tools/releases/tag/3.2.1).
- [[#273](https://github.com/nf-core/proteinfold/issues/273)] - Fixes comparison report to correctly label msa coverage plots with corresponding method label.
- [[#290](https://github.com/nf-core/proteinfold/issues/290)] - Update Alphafold2 split images to make them compatible Hopper gpus.
- [[PR #302](https://github.com/nf-core/proteinfold/pull/302)] - Fix HF3 dbs and max_template_date.
- [[PR #305](https://github.com/nf-core/proteinfold/pull/305)] - Stop RFAA and HF3 symlinking scripts into workdir.
- [[PR #306](https://github.com/nf-core/proteinfold/pull/306)] - extract_output.py -> extract_metrics.py so pLDDT, MSA, PAE emitted as raw data .tsv files
- [[PR #307](https://github.com/nf-core/proteinfold/pull/307)] - Update Boltz-1 boilerplate and formatting.
- [[PR #314](https://github.com/nf-core/proteinfold/pull/314)] - Fix extract metrics for broken modules.
- [[PR #312](https://github.com/nf-core/proteinfold/pull/312)] - pTM & ipTM metrics now extracted
- [[PR #315](https://github.com/nf-core/proteinfold/pull/315)] - Add global db flag.
- [[#263](https://github.com/nf-core/proteinfold/issues/263)] - Removed broken colabfold options (`auto` and `alphafold2`)
- [[PR #316](https://github.com/nf-core/proteinfold/pull/316)] - Add process_gpu label to modules which use GPU.
- [[PR #319](https://github.com/nf-core/proteinfold/pull/319)] - Update boltz workflow to accept YAML as input.
- [[PR #322](https://github.com/nf-core/proteinfold/pull/322)] - Updates and reorganises the reference database directory structure.
- [[PR #329](https://github.com/nf-core/proteinfold/pull/329)] - Updates Boltz module to include Boltz-2.
- [[PR #332](https://github.com/nf-core/proteinfold/pull/332)] - Fix rare superposition bug in reports.
- [[PR #333](https://github.com/nf-core/proteinfold/pull/333)] - Updates the RFAA dockerfile for better versioning and smaller image size.
- [[PR #335](https://github.com/nf-core/proteinfold/pull/335)] - Update pipeline template to [nf-core/tools 3.3.1](https://github.com/nf-core/tools/releases/tag/3.3.1).
- [[PR #346](https://github.com/nf-core/proteinfold/pull/346)] - Update pipeline template to [nf-core/tools 3.3.2](https://github.com/nf-core/tools/releases/tag/3.3.2).
- [[PR #351](https://github.com/nf-core/proteinfold/pull/351)] - add chain-wise (i)pTM values and summary file for AF3-generation codes.
- [[PR #355](https://github.com/nf-core/proteinfold/pull/355)] - Remove unneccesary params from Boltz and Helixfold3 modes.
- [[PR #356](https://github.com/nf-core/proteinfold/pull/356)] - Update AF2 defaults to use split mode and monomer_ptm model.
- [[PR #357](https://github.com/nf-core/proteinfold/pull/357)] - Update ColabFold module and image.
- [[PR #359](https://github.com/nf-core/proteinfold/pull/359)] - Harmonize parameters across modes.
- [[PR #360](https://github.com/nf-core/proteinfold/pull/360)] - Rename some DBs paths in the run modules so they are equal to those when DBs are downloaded.
- [[PR #362](https://github.com/nf-core/proteinfold/pull/355)] - Update boltz Dockerfile and image pinning specific version (2.0.3).
- [[#364](https://github.com/nf-core/proteinfold/issues/364)] - Move Dockerfiles to its corresponding module.
- [[PR #370](https://github.com/nf-core/proteinfold/pull/370)] - Fix extract chain metrics.
- [[#367](https://github.com/nf-core/proteinfold/issues/367)] - Boltz post-processing crashes.
- [[#368](https://github.com/nf-core/proteinfold/issues/368)] - Helixfold3 iPTM output missing when dealing with monomers make the process to fail.

### Parameters

| Old parameter                | New parameter                    |
| ---------------------------- | -------------------------------- |
|                              | `--alphafold2_pdb_obsolete_path` |
| `--small_bfd_link`           | `--alphafold2_small_bfd_link`    |
| `--mgnify_link`              | `--alphafold2_mgnify_link`       |
| `--pdb_mmcif_link`           | `--alphafold2_pdb_mmcif_link`    |
| `--uniref30_alphafold2_link` | `--alphafold2_uniref30_link`     |
| `--uniref90_link`            | `--alphafold2_uniref90_link`     |
| `--pdb_seqres_link`          | `--alphafold2_pdb_seqres_link`   |
| `--small_bfd_path`           | `--alphafold2_small_bfd_path`    |
| `--mgnify_path_alphafold2`   | `--alphafold2_mgnify_path`       |
| `--pdb_mmcif_path`           | `--alphafold2_pdb_mmcif_path`    |
| `--uniref30_alphafold2_path` | `--alphafold2_uniref30_path`     |
| `--uniref90_path`            | `--alphafold2_uniref90_path`     |
| `--pdb_seqres_path`          | `--alphafold2_pdb_seqres_path`   |
| `--uniprot_path`             | `--alphafold2_uniprot_path`      |
|                              | `--alphafold3_small_bfd_link`    |
|                              | `--alphafold3_mgnify_link`       |
|                              | `--alphafold3_uniref90_link`     |
|                              | `--alphafold3_pdb_seqres_link`   |
|                              | `--alphafold3_uniprot_link`      |
|                              | `--alphafold3_small_bfd_path`    |
|                              | `--alphafold3_params_path`       |
|                              | `--alphafold3_mgnify_path`       |
|                              | `--alphafold3_pdb_mmcif_path`    |
|                              | `--alphafold3_uniref90_path`     |
|                              | `--alphafold3_pdb_seqres_path`   |
|                              | `--alphafold3_uniprot_path`      |
|                              | `--boltz_model`                  |
|                              | `--boltz_out_dir`                |
|                              | `--boltz_output_format`          |
|                              | `--boltz_use_msa_server`         |
|                              | `--boltz_msa_server_url`         |
|                              | `--boltz_use_potentials`         |
|                              | `--boltz_write_full_pae`         |
|                              | `--boltz2_aff_path`              |
|                              | `--boltz2_conf_path`             |
|                              | `--boltz2_mols_path`             |
|                              | `--boltz_model_path`             |
|                              | `--boltz_ccd_path`               |
|                              | `--boltz_db`                     |
|                              | `--boltz2_aff_link`              |
|                              | `--boltz2_conf_link`             |
|                              | `--boltz2_mols_link`             |
|                              | `--boltz_model_link`             |
|                              | `--boltz_ccd_link`               |

> **NB:** Parameter has been **updated** if both old and new parameter information is present.
> **NB:** Parameter has been **added** if just the new parameter information is present.
> **NB:** Parameter has been **removed** if parameter information is

## [[1.1.1](https://github.com/nf-core/proteinfold/releases/tag/1.1.1)] - 2025-07-30

### Enhancements & fixes

- Minor patch release to fix multiqc report.

## [[1.1.0](https://github.com/nf-core/proteinfold/releases/tag/1.1.0)] - 2025-06-25

### Credits

Special thanks to the following for their contributions to the release:

- [Adam Talbot](https://github.com/adamrtalbot)
- [Athanasios Baltzis](https://github.com/athbaltzis)
- [Björn Langer](https://github.com/bjlang)
- [Igor Trujnara](https://github.com/itrujnara)
- [Matthias Hörtenhuber](https://github.com/mashehu)
- [Maxime Garcia](https://github.com/maxulysse)
- [Júlia Mir Pedrol](https://github.com/mirpedrol)
- [Ziad Al-Bkhetan](https://github.com/ziadbkh)

Thank you to everyone else that has contributed by reporting bugs, enhancements or in any other way, shape or form.

## [[1.1.0](https://github.com/nf-core/proteinfold/releases/tag/1.1.0)] - 2025-06-21

### Enhancements & fixes

- [[#80](https://github.com/nf-core/proteinfold/pull/80)] - Add `accelerator` directive to GPU processes when `params.use_gpu` is true.
- [[#81](https://github.com/nf-core/proteinfold/pull/81)] - Support multiline fasta for colabfold multimer predictions.
- [[#89](https://github.com/nf-core/proteinfold/pull/89)] - Fix issue with excessive symlinking in the pdb_mmcif database.
- [[PR #91](https://github.com/nf-core/proteinfold/pull/91)] - Update ColabFold version to 1.5.2 and AlphaFold version to 2.3.2
- [[PR #92](https://github.com/nf-core/proteinfold/pull/92)] - Add ESMFold workflow to the pipeline.
- Update metro map to include ESMFold workflow.
- Update modules to remove quay from container url.
- [[nf-core/tools#2286](https://github.com/nf-core/tools/issues/2286)] - Set default container registry outside profile scope.
- [[PR #97](https://github.com/nf-core/proteinfold/pull/97)] - Fix issue with uniref30 missing path when using the full BFD database in AlphaFold.
- [[PR #100](https://github.com/nf-core/proteinfold/pull/100)] - Update containers for AlphaFold2 and ColabFold local modules.
- [[PR #105](https://github.com/nf-core/proteinfold/pull/105)] - Update COLABFOLD_BATCH docker container, metro map figure and nextflow schema description.
- [[PR #106](https://github.com/nf-core/proteinfold/pull/106)] - Add `singularity.registry = 'quay.io'` and bump NF version to 23.04.0
- [[#108](https://github.com/nf-core/proteinfold/issues/108)] - Fix gunzip error when providing too many files when downloading PDBMMCIF database.
- [[PR #111](https://github.com/nf-core/proteinfold/pull/111)] - Update pipeline template to [nf-core/tools 2.9](https://github.com/nf-core/tools/releases/tag/2.9).
- [[PR #112](https://github.com/nf-core/rnaseq/pull/112)] - Use `nf-validation` plugin for parameter and samplesheet validation.
- [[#113](https://github.com/nf-core/proteinfold/pull/113)] - Include esmfold dbs for full data sets.
- [[PR #114](https://github.com/nf-core/rnaseq/pull/114)] - Update paths to test dbs.
- [[PR #117](https://github.com/nf-core/proteinfold/pull/117)] - Update pipeline template to [nf-core/tools 2.10](https://github.com/nf-core/tools/releases/tag/2.10).
- [[PR #132](https://github.com/nf-core/proteinfold/pull/132)] - Remove `lib/` directory.
- [[#135](https://github.com/nf-core/proteinfold/issues/135)] - Reduce Alphafold Docker images sizes.
- [[#115](https://github.com/nf-core/proteinfold/issues/115)] - Throw message error when profile conda is used.
- [[#131](https://github.com/nf-core/proteinfold/issues/131)] - Add esmfold small tests.
- [[#144](https://github.com/nf-core/proteinfold/issues/144)] - Force value channels when providing dbs (downloaded) in `main.nf` to enable the processing of multiple samples.
- [[#147](https://github.com/nf-core/proteinfold/issues/147)] - Update modules to last version.
- [[#145](https://github.com/nf-core/proteinfold/issues/145)] - Implement test to check the processes/subworkflows triggered when downloading the databases.
- [[#130](https://github.com/nf-core/proteinfold/issues/130)] - Add `--skip_multiqc` parameter.
- [[PR #154](https://github.com/nf-core/proteinfold/pull/154)] - Update pipeline template to [nf-core/tools 2.14.1](https://github.com/nf-core/tools/releases/tag/2.14.1).
- [[#148](https://github.com/nf-core/proteinfold/issues/148)] - Update Colabfold DBs.
- [[PR #159](https://github.com/nf-core/proteinfold/pull/159)] - Update `mgnify` paths to new available version.
- [[PR ##163](https://github.com/nf-core/proteinfold/pull/163)] - Fix full test CI.
- [[#150]](https://github.com/nf-core/proteinfold/issues/150)] - Add thanks to the AWS Open Data Sponsorship program in `README.md`.
- [[PR ##166](https://github.com/nf-core/proteinfold/pull/166)] - Create 2 different parameters for Colabfold and ESMfold number of recycles.

### Parameters

| Old parameter         | New parameter                            |
| --------------------- | ---------------------------------------- |
| `--uniclust30`        |                                          |
| `--bfd`               | `--bfd_link`                             |
| `--small_bfd`         | `--small_bfd_link`                       |
| `--alphafold2_params` | `--alphafold2_params_link`               |
| `--mgnify`            | `--mgnify_link`                          |
| `--pdb70`             | `--pdb70_link`                           |
| `--pdb_mmcif`         | `--pdb_mmcif_link`                       |
| `--pdb_obsolete`      | `--pdb_obsolete_link`                    |
| `--uniref90`          | `--uniref90_link`                        |
| `--pdb_seqres`        | `--pdb_seqres_link`                      |
| `--uniprot_sprot`     | `--uniprot_sprot_link`                   |
| `--uniprot_trembl`    | `--uniprot_trembl_link`                  |
| `--uniclust30_path`   | `--uniref30_alphafold2_path`             |
| `--uniref30`          | `--colabfold_uniref30_link`              |
| `--uniref30_path`     | `--colabfold_uniref30_path`              |
| `--num_recycle`       | `--num_recycles_colabfold`               |
|                       | `--num_recycles_esmfold`                 |
|                       | `--uniref30_alphafold2_link`             |
|                       | `--esmfold_db`                           |
|                       | `--esmfold_model_preset`                 |
|                       | `--esmfold_3B_v1`                        |
|                       | `--esm2_t36_3B_UR50D`                    |
|                       | `--esm2_t36_3B_UR50D_contact_regression` |
|                       | `--esmfold_params_path`                  |
|                       | `--skip_multiqc`                         |
|                       | `--rosettafold_all_atom_db`              |
|                       | `--helixfold3_db`                        |

> **NB:** Parameter has been **updated** if both old and new parameter information is present.
> **NB:** Parameter has been **added** if just the new parameter information is present.
> **NB:** Parameter has been **removed** if parameter information isn't present.

## 1.0.0 - White Silver Reebok

Initial release of nf-core/proteinfold, created with the [nf-core](https://nf-co.re/) template.

### Enhancements & fixes

- Updated pipeline template to [nf-core/tools 2.7.2](https://github.com/nf-core/tools/releases/tag/2.7.2)
