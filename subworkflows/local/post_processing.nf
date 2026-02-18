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
    skip_visualisation
    requested_modes_size
    ch_report_input
    ch_report_template
    ch_comparison_template
    skip_foldseek
    foldseek_db
    foldseek_db_path
    skip_multiqc
    outdir
    ch_versions
    ch_multiqc_rep
    ch_multiqc_config
    ch_multiqc_custom_config
    ch_multiqc_logo
    ch_multiqc_methods_description
    ch_top_ranked_model

    main:
    ch_comparison_report_files = channel.empty()

    if (!skip_visualisation){
        GENERATE_REPORT(
            ch_report_input,
            ch_report_template
        )
        ch_versions = ch_versions.mix(GENERATE_REPORT.out.versions)

        if (requested_modes_size > 1){
            ch_dummy_file = channel.fromPath("$projectDir/assets/NO_FILE")

            def esm = ch_top_ranked_model.filter { it ->it[0].model == 'esmfold' }
            def not_esm = ch_top_ranked_model.filter { it -> it[0].model != 'esmfold' }

            esm = esm
                    .map { it ->
                        [it[0], it[1]]
                    }
                    .merge(ch_dummy_file)

            not_esm = not_esm
                        .map { it ->  [it[0], it[1]] }
                        .join(GENERATE_REPORT.out.sequence_coverage)

            not_esm.mix(esm).set{ch_comparison_report_files}

            ch_comparison_report_files
                .map { it ->
                    [["id": it[0].id], it[0], it[1], it[2]]
                }
                .groupTuple(by: [0], size: requested_modes_size)
                .map { it ->
                    it[0].models=it[1].join(',');
                    [it[0], it[2], it[3]]
                }
                .set { ch_comparison_report_input }

            COMPARE_STRUCTURES(
                ch_comparison_report_input
                    .map { it ->
                        [it[0], it[1].collect { file -> file.name} ]
                    },
                ch_comparison_report_input
                    .map { it ->
                        [ it[0], it[2].collect { file -> file.name } ]
                    },
                ch_comparison_report_input
                    .map { it ->
                        (it[1] + it[2]).unique()
                    },
                ch_comparison_template
            )
            ch_versions = ch_versions.mix(COMPARE_STRUCTURES.out.versions)
        }
    }

    if (!skip_foldseek) {
        ch_foldseek_db = channel.value([
            [
                id: foldseek_db,
            ],
            file(foldseek_db_path, checkIfExists: true)
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
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'proteinfold_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_report = channel.empty()

    if (!skip_multiqc) {
        summary_params           = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
        ch_workflow_summary      = channel.value(paramsSummaryMultiqc(summary_params))
        ch_methods_description   = channel.value(methodsDescriptionText(ch_multiqc_methods_description))

        ch_multiqc_files = channel.empty()
        ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)

        ch_multiqc_rep
            .combine(
                ch_multiqc_files
                    .collect()
                    .map { it -> [it] }
            )

        MULTIQC (
            ch_multiqc_rep
                .combine(
                    ch_multiqc_files
                        .collect()
                        .map { it -> [it] }
                )
                .map { it -> [ it[0], it[1] + it[2] ] },
            ch_multiqc_config,
            ch_multiqc_custom_config
                .collect()
                .ifEmpty([]),
            ch_multiqc_logo
                .collect()
                .ifEmpty([]),
            [],
            []
        )
        ch_multiqc_report = MULTIQC.out.report.toList()
    }

    emit:
    versions       = ch_versions
    multiqc_report = ch_multiqc_report
}
