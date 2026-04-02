//
// Post processing analysis for the predicted structures
//

//
// SUBWORKFLOW: Consisting entirely of nf-core/modules
//
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from './utils_nfcore_proteinfold_pipeline'

include { GENERATE_REPORT     } from '../../modules/local/generate_report'
include { COMPARE_STRUCTURES  } from '../../modules/local/compare_structures'
include { FOLDSEEK_EASYSEARCH } from '../../modules/nf-core/foldseek/easysearch/main'
include { MULTIQC             } from '../../modules/nf-core/multiqc/main'


workflow POST_PROCESSING {

    take:
    requested_modes_size
    ch_report_input
    ch_report_template
    ch_versions
    ch_top_ranked_model

    main:
    ch_comparison_report_files = channel.empty()

    if (!params.skip_visualisation){
        ch_report_input
            .multiMap { meta, pdbs, msa, pae ->
                full:     [meta, pdbs, msa, pae]
                msa_only: [meta, msa]
            }
            .set { ch_report_split }

        GENERATE_REPORT(
            ch_report_split.full,
            ch_report_template
        )
        ch_versions = ch_versions.mix(GENERATE_REPORT.out.versions)

        if (requested_modes_size > 1){
            // Multi-mode comparison: group top-ranked structures and MSA data from all modes
            ch_top_ranked_model
                .join(ch_report_split.msa_only)
                .map { meta, pdb, msa ->
                    [["id": meta.id], meta, pdb, msa]
                }
                .groupTuple(by: [0], size: requested_modes_size)
                .map { key, model_meta_list, pdbs, msas ->
                    def models_str = model_meta_list.collect { it.model }.join(',')
                    [key + [models: models_str], pdbs, msas]
                }
                .multiMap { meta, pdbs, msas ->
                    def valid_msas = msas.findAll { !it.name.startsWith("DUMMY_") }
                    pdbs:     [meta, pdbs.collect { it.name }]
                    msas:     [meta, valid_msas.collect { it.name }]
                    allfiles: (pdbs + valid_msas).unique()
                }
                .set { ch_split }

            COMPARE_STRUCTURES(
                ch_split.pdbs,
                ch_split.msas,
                ch_split.allfiles,
                ch_report_template
            )
            ch_versions = ch_versions.mix(COMPARE_STRUCTURES.out.versions)
        }
    }

    if (!params.skip_foldseek) {
        ch_foldseek_db = channel.value([
            [
                id: params.foldseek_db,
            ],
            file(params.foldseek_db_path, checkIfExists: true)
        ])
        FOLDSEEK_EASYSEARCH(
            ch_top_ranked_model,
            ch_foldseek_db
        )
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'proteinfold_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_report = channel.empty()

    if (!params.skip_multiqc) {
        ch_multiqc_config        = channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true).first()
        ch_multiqc_custom_config = params.multiqc_config   ? channel.fromPath(params.multiqc_config).first()                                                                       : channel.empty()
        ch_multiqc_logo          = params.multiqc_logo     ? channel.fromPath(params.multiqc_logo).first()                                                                         : channel.empty()
        ch_multiqc_methods_desc  = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

        summary_params         = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
        ch_workflow_summary    = channel.value(paramsSummaryMultiqc(summary_params))
        ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_methods_desc))

        ch_multiqc_files = ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml')
            .mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
            .mix(ch_collated_versions)

        MULTIQC (
            ch_multiqc_files.collect().map { [[id: 'proteinfold', model: 'proteinfold'], it] },
            ch_multiqc_config,
            ch_multiqc_custom_config.toList(),
            ch_multiqc_logo.toList(),
            [],
            []
        )
        ch_multiqc_report = MULTIQC.out.report.toList()
    }

    emit:
    versions       = ch_versions
    multiqc_report = ch_multiqc_report
}
