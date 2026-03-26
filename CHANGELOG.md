# nf-core/proteinfold: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [[2.0.0](https://github.com/nf-core/proteinfold/releases/tag/2.0.0)] - 2026-03-26

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
- [[PR #354](https://github.com/nf-core/proteinfold/pull/354)] - Update documentation with mode specific usage, capabilities.
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
- [[#369](https://github.com/nf-core/proteinfold/issues/369)] - Download all Alphafold3 DBs.
- [[PR #350](https://github.com/nf-core/proteinfold/pull/350)] - PAE of model 0 in Boltz HTML report, AlphaFold2 to pass the build system
- [[PR #377](https://github.com/nf-core/proteinfold/pull/377)] - Fix sequence msa synch for af2 split.
- [[#380](https://github.com/nf-core/proteinfold/issues/380)] - Fixes alphafold2_model_preset bug on retry.
- [[#382](https://github.com/nf-core/proteinfold/issues/382)] - Readds `--full_dbs` as a global option.
- [[#378](https://github.com/nf-core/proteinfold/issues/378)] - Fix nested obsolete pdbs from pdb70.
- [[#388](https://github.com/nf-core/proteinfold/issues/388)] - Fix colabfold prefix handling for output metrics.
- [[#387](https://github.com/nf-core/proteinfold/issues/387)] - Fix alphafold2_standard obsolete.dat path error.
- [[#389](https://github.com/nf-core/proteinfold/issues/389)] - Locked version numbers for HelixFold3 image to prevent bug caused by newer mamba versions.
- [[PR #397](https://github.com/nf-core/proteinfold/pull/397)] - Fix AF2 mgnify handling and improve version reporting for AlphaFold2 containers.
- [[PR #398](https://github.com/nf-core/proteinfold/pull/398)] - Fix issues with PREPARE_DBS subworkflows.
- [[PR #399](https://github.com/nf-core/proteinfold/pulls/399)] - Update alphafold2 and alphafold2_pred Dockerfiles.
- [[PR #404](https://github.com/nf-core/proteinfold/pulls/404)] - Boltz cache files moved to workdir, fixed version checks and Boltz stubRun.
- [[#401](https://github.com/nf-core/proteinfold/issues/401)] - Get rid of symlinking in the prediction tools processes when using "PREPARE_DBS" subworkflows
- [[#410](https://github.com/nf-core/proteinfold/issues/410)] - Switch RosettaFold2NA to Boltz-style multi-chain FASTA inputs and drop the interactions sheet.
- [[PR #407](https://github.com/nf-core/proteinfold/pulls/407)] - Several changes to meet nf-core standards.
- [[PR #409](https://github.com/nf-core/proteinfold/pulls/409)] - Force single pdb workflow outputs to return as a list
- [[PR #396](https://github.com/nf-core/proteinfold/pulls/396)] - Split ColabFold into separate optimised containers with version pinning and significant size reduction.
- [[#412](https://github.com/nf-core/proteinfold/issues/412)] - Substitute "/" with "\_" from fasta headers used to name files when using "--split_fasta".
- [[PR #424](https://github.com/nf-core/proteinfold/pulls/424)] - Bump docker image version for release to 2.0.0, make code more friendly with Nextflow language server and other format issues/fixes.
- [[#423](https://github.com/nf-core/proteinfold/issues/423)] - Generate json workflow using bioflow-insight.
- [[#425](https://github.com/nf-core/proteinfold/issues/425)] - Pass as a single input channel fasta and features to get rid of meta2 in RUN_ALPHAFOLD2_PRED.
- [[#440](https://github.com/nf-core/proteinfold/issues/440)] - Support single-letter RF2NA type tags (`type=P/R/D/S`) in ROSETTAFOLD2NA FASTA headers.
- [[PR #442](https://github.com/nf-core/proteinfold/pulls/442)] - Bump version 2.6.1 of nf-schema, Nextflow minimum version to 25.10.2 and update utils_nfschema_plugin subworkflow.
- [[PR #443](https://github.com/nf-core/proteinfold/pull/443)] - Add documentation guide for contributing new prediction modes.
- [[PR #446](https://github.com/nf-core/proteinfold/pulls/446)] - Fix warnings from Nextflow lint.
- [[PR #451](https://github.com/nf-core/proteinfold/pulls/451)] - Remove af2 multimer padding from msa plots.
- [[#417](https://github.com/nf-core/proteinfold/issues/417)] - Add `boltz_use_kernels` parameter to enable/disable using optimized Triton-based CUDA kernels CUDA kernels for Boltz inference.
- [[#417](https://github.com/nf-core/proteinfold/issues/417)] - Handle incompatible CUDA kernel errors in Boltz by automatically retrying with `--use_kernels` false.
- [[#285](https://github.com/nf-core/proteinfold/issues/285)] - Adding contributors to manifest.
- [[PR #460](https://github.com/nf-core/proteinfold/pulls/460)] - Use `nvidia-smi` to obtain number of SM.
- [[PR #454](https://github.com/nf-core/proteinfold/pulls/454)] - Update publishdir patterns for alphafold2 modules.
- [[PR #458](https://github.com/nf-core/proteinfold/pulls/458)] - Update publishdir patterns for colabfold module.
- [[#313](https://github.com/nf-core/proteinfold/issues/313)] - Harmonize colabfold metrics extraction with other modes.
- [[#455](https://github.com/nf-core/proteinfold/issues/455)] - Fix colabfold monomer inheriting id from fasta header.
- [[#457](https://github.com/nf-core/proteinfold/issues/457)] - Fix colabfold multimer always downloading model weights.
- [[PR #461](https://github.com/nf-core/proteinfold/pulls/461)] - Update publishdir patterns for HelixFold3 module
- [[PR #462](https://github.com/nf-core/proteinfold/pulls/462)] - Update publishdir patterns for RoseTTAFold-All-Atom modules
- [[PR #464](https://github.com/nf-core/proteinfold/pulls/454)] - Update publishdir patterns for Boltz module
- [[PR #466](https://github.com/nf-core/proteinfold/pulls/464)] - Update module conf and publishdir patterns for ESMFold, pass through container args
- [[PR #469](https://github.com/nf-core/proteinfold/pulls/454)] - HTML reports now in /reports output directory
- [[PR #468](https://github.com/nf-core/proteinfold/pulls/468)] - Update publishdir patterns for Alphafold3 module
- [[PR #471](https://github.com/nf-core/proteinfold/pulls/471)] - Update publishdir patterns for Rosettafold2na module
- [[#473](https://github.com/nf-core/proteinfold/issues/473)] - Add nf-test for `rosettafold-aa`, `rosettafold2na`, `helixfold3` and `boltz` modes.
- [[PR #475](https://github.com/nf-core/proteinfold/pulls/475)] - Update and simplify outputs.md with the latest structure
- [[#480](https://github.com/nf-core/proteinfold/issues/480)] - Make version reporting consistent for all local modules.
- [[PR #482](https://github.com/nf-core/proteinfold/pulls/482)] - Update utils_nfschema to fix help message with strict syntax.
- [[PR #483](https://github.com/nf-core/proteinfold/pulls/483)] - Move foldseek logic to the `post_processing` subworkflow and set sensible time to aria2 processes.
- [[PR #492](https://github.com/nf-core/proteinfold/pulls/492)] - Clean TODOs from code and create issues instead for 2.0.0 release preparation.
- [[PR #493](https://github.com/nf-core/proteinfold/pulls/493)] - Standardise Dockerfiles labels and bump version 2.0.0 to prepare release.
- [[#494](https://github.com/nf-core/proteinfold/issues/494)] - Publish Colabfold DBs when downloaded to be directly consumable using `colabfold_db` parameter.
- [[#496](https://github.com/nf-core/proteinfold/issues/496)] - Publish all DBs when downloaded to be directly consumable using the corresponding mode parameter.
- [[#494](https://github.com/nf-core/proteinfold/issues/494)] - Publish Colabfold DBs when downloaded to be directly consumable using `colabfold_db` parameter.
- [[#499](https://github.com/nf-core/proteinfold/issues/499)] - Get rid of `ENTRYPOINT` in alphafold2 dockerfiles.
- [[PR #501](https://github.com/nf-core/proteinfold/pulls/501)] - Move python code of `BOLTZ_FASTA` to a python script in `bin`.
- [[#503](https://github.com/nf-core/proteinfold/issues/503)] - Add checkIfExists validation to user-provided database paths across all prepare DB subworkflows.
- [[#507](https://github.com/nf-core/proteinfold/issues/507)] - Implement missing full tests and check that the others work before release 2.0.0.
- [[PR #509](https://github.com/nf-core/proteinfold/pulls/509)] - Setup gpu environment for AWS full tests.
- [[#519](https://github.com/nf-core/proteinfold/issues/519)] - Fix AWS full test before release 2.0.0.
- [[PR #525](https://github.com/nf-core/proteinfold/pulls/525)] - Reduce AlphaFold2 multimer full test to a single replicate.
- [[PR #531](https://github.com/nf-core/proteinfold/pulls/531)] - Fix alphafold2_random_seed type.
- [[PR #538](https://github.com/nf-core/proteinfold/pulls/538)] - Bump version 2.0.0 for release preparation.
- [[PR #563](https://github.com/nf-core/proteinfold/pulls/563)] - Fix boltz csv sync.
- [[PR #570](https://github.com/nf-core/proteinfold/pulls/570)] - Update parameters table in changelog.

### Parameters

| Old parameter                | New parameter                               |
| ---------------------------- | ------------------------------------------- |
| `--max_template_date`        | `--alphafold2_max_template_date`            |
| `--bfd_link`                 | `--alphafold2_bfd_link`                     |
| `--small_bfd_link`           | `--alphafold2_small_bfd_link`               |
| `--mgnify_link`              | `--alphafold2_mgnify_link`                  |
| `--pdb70_link`               | `--alphafold2_pdb70_link`                   |
| `--pdb_mmcif_link`           | `--alphafold2_pdb_mmcif_link`               |
| `--pdb_obsolete_link`        | `--alphafold2_pdb_obsolete_link`            |
| `--uniref30_alphafold2_link` | `--alphafold2_uniref30_link`                |
| `--uniref90_link`            | `--alphafold2_uniref90_link`                |
| `--pdb_seqres_link`          | `--alphafold2_pdb_seqres_link`              |
| `--uniprot_sprot_link`       | `--alphafold2_uniprot_sprot_link`           |
| `--uniprot_trembl_link`      | `--alphafold2_uniprot_trembl_link`          |
| `--bfd_path`                 | `--alphafold2_bfd_path`                     |
| `--small_bfd_path`           | `--alphafold2_small_bfd_path`               |
| `--mgnify_path`              | `--alphafold2_mgnify_path`                  |
| `--pdb70_path`               | `--alphafold2_pdb70_path`                   |
| `--pdb_mmcif_path`           | `--alphafold2_pdb_mmcif_path`               |
| `--uniref30_alphafold2_path` | `--alphafold2_uniref30_path`                |
| `--uniref90_path`            | `--alphafold2_uniref90_path`                |
| `--pdb_seqres_path`          | `--alphafold2_pdb_seqres_path`              |
| `--uniprot_path`             | `--alphafold2_uniprot_path`                 |
| `--colabfold_server`         | `--use_msa_server`                          |
| `--host_url`                 | `--msa_server_url`                          |
| `--uniref30_colabfold_link`  | `--colabfold_uniref30_link`                 |
| `--uniref30_colabfold_path`  | `--colabfold_uniref30_path`                 |
| `--colabfold_db_path`        | `--colabfold_envdb_path`                    |
| `--create_colabfold_index`   | `--colabfold_create_index`                  |
| `--use_amber`                | `--colabfold_use_amber`                     |
| `--use_templates`            | `--colabfold_use_templates`                 |
| `--db_load_mode`             | `--colabfold_db_load_mode`                  |
| `--num_recycles_colabfold`   | `--colabfold_num_recycles`                  |
| `--num_recycles_esmfold`     | `--esmfold_num_recycles`                    |
|                              | `--save_intermediates`                      |
|                              | `--split_fasta`                             |
|                              | `--db`                                      |
|                              | `--alphafold2_full_dbs`                     |
|                              | `--uniref30_prefix`                         |
|                              | `--skip_visualisation`                      |
|                              | `--skip_foldseek`                           |
|                              | `--foldseek_easysearch_arg`                 |
|                              | `--alphafold2_random_seed`                  |
|                              | `--alphafold2_pdb_obsolete_path`            |
|                              | `--alphafold3_db`                           |
|                              | `--alphafold3_small_bfd_link`               |
|                              | `--alphafold3_small_bfd_path`               |
|                              | `--alphafold3_mgnify_link`                  |
|                              | `--alphafold3_mgnify_path`                  |
|                              | `--alphafold3_pdb_mmcif_link`               |
|                              | `--alphafold3_pdb_mmcif_path`               |
|                              | `--alphafold3_uniref90_link`                |
|                              | `--alphafold3_uniref90_path`                |
|                              | `--alphafold3_pdb_seqres_link`              |
|                              | `--alphafold3_pdb_seqres_path`              |
|                              | `--alphafold3_uniprot_link`                 |
|                              | `--alphafold3_uniprot_path`                 |
|                              | `--alphafold3_params_path`                  |
|                              | `--alphafold3_rnacentral_link`              |
|                              | `--alphafold3_rnacentral_path`              |
|                              | `--alphafold3_nt_rna_link`                  |
|                              | `--alphafold3_nt_rna_path`                  |
|                              | `--alphafold3_rfam_link`                    |
|                              | `--alphafold3_rfam_path`                    |
|                              | `--boltz_model`                             |
|                              | `--boltz_use_potentials`                    |
|                              | `--boltz_use_kernels`                       |
|                              | `--boltz_ccd_link`                          |
|                              | `--boltz_ccd_path`                          |
|                              | `--boltz_model_link`                        |
|                              | `--boltz_model_path`                        |
|                              | `--boltz2_aff_link`                         |
|                              | `--boltz2_aff_path`                         |
|                              | `--boltz2_conf_link`                        |
|                              | `--boltz2_conf_path`                        |
|                              | `--boltz2_mols_link`                        |
|                              | `--boltz2_mols_path`                        |
|                              | `--boltz_db`                                |
|                              | `--helixfold3_db`                           |
|                              | `--helixfold3_precision`                    |
|                              | `--helixfold3_infer_times`                  |
|                              | `--helixfold3_max_template_date`            |
|                              | `--helixfold3_uniclust30_link`              |
|                              | `--helixfold3_uniclust30_path`              |
|                              | `--helixfold3_ccd_preprocessed_link`        |
|                              | `--helixfold3_ccd_preprocessed_path`        |
|                              | `--helixfold3_rfam_link`                    |
|                              | `--helixfold3_rfam_path`                    |
|                              | `--helixfold3_init_models_link`             |
|                              | `--helixfold3_init_models_path`             |
|                              | `--helixfold3_bfd_link`                     |
|                              | `--helixfold3_bfd_path`                     |
|                              | `--helixfold3_small_bfd_link`               |
|                              | `--helixfold3_small_bfd_path`               |
|                              | `--helixfold3_uniprot_sprot_link`           |
|                              | `--helixfold3_uniprot_trembl_link`          |
|                              | `--helixfold3_uniprot_path`                 |
|                              | `--helixfold3_pdb_seqres_link`              |
|                              | `--helixfold3_pdb_seqres_path`              |
|                              | `--helixfold3_uniref90_link`                |
|                              | `--helixfold3_uniref90_path`                |
|                              | `--helixfold3_mgnify_link`                  |
|                              | `--helixfold3_mgnify_path`                  |
|                              | `--helixfold3_pdb_mmcif_link`               |
|                              | `--helixfold3_pdb_mmcif_path`               |
|                              | `--helixfold3_obsolete_link`                |
|                              | `--helixfold3_obsolete_path`                |
|                              | `--helixfold3_maxit_src_link`               |
|                              | `--helixfold3_maxit_src_path`               |
|                              | `--rosettafold_all_atom_db`                 |
|                              | `--rosettafold_all_atom_uniref30_link`      |
|                              | `--rosettafold_all_atom_uniref30_path`      |
|                              | `--rosettafold_all_atom_pdb100_link`        |
|                              | `--rosettafold_all_atom_pdb100_path`        |
|                              | `--rosettafold_all_atom_bfd_link`           |
|                              | `--rosettafold_all_atom_bfd_path`           |
|                              | `--rosettafold_all_atom_paper_weights_link` |
|                              | `--rosettafold_all_atom_paper_weights_path` |
|                              | `--rosettafold2na_db`                       |
|                              | `--rosettafold2na_uniref30_link`            |
|                              | `--rosettafold2na_uniref30_path`            |
|                              | `--rosettafold2na_bfd_link`                 |
|                              | `--rosettafold2na_bfd_path`                 |
|                              | `--rosettafold2na_pdb100_link`              |
|                              | `--rosettafold2na_pdb100_path`              |
|                              | `--rosettafold2na_weights_link`             |
|                              | `--rosettafold2na_weights_path`             |
|                              | `--rosettafold2na_rna_path`                 |
|                              | `--rfam_full_region_link`                   |
|                              | `--rfam_cm_link`                            |
|                              | `--rnacentral_rfam_annotations_link`        |
|                              | `--rnacentral_id_mapping_link`              |
|                              | `--rnacentral_sequences_link`               |
| `--max_memory`               |                                             |
| `--max_cpus`                 |                                             |
| `--max_time`                 |                                             |

> **NB:** Parameter has been **updated** if both old and new parameter information is present.
> **NB:** Parameter has been **added** if just the new parameter information is present.
> **NB:** Parameter has been **removed** if parameter information is present only for the old parameter.

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
