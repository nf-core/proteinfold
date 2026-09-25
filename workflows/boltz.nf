/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC } from '../modules/nf-core/multiqc/main'
include { BOLTZ_FASTA } from '../modules/local/boltz_fasta'
include { BOLTZ_YAML_TO_COLABFOLD_FASTA } from '../modules/local/boltz_yaml_to_colabfold_fasta'
include { SPLIT_MSA } from '../modules/local/split_msa'
include { MMSEQS_COLABFOLDSEARCH } from '../modules/local/mmseqs_colabfoldsearch'

//
// MODULE: Boltz
//
include { RUN_BOLTZ } from '../modules/local/run_boltz'
include { collectMultiqcMetrics } from '../subworkflows/local/utils_nfcore_proteinfold_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow BOLTZ {

    take:
    ch_samplesheet  // channel: samplesheet read from --input
    ch_boltz_ccd    // channel: [ path(boltz_ccd) ]
    ch_boltz_model  // channel: [ path(model) ]
    ch_boltz2_aff   // channel: [ path(boltz2_aff) ]
    ch_boltz2_conf  // channel: [ path(boltz2_conf) ]
    ch_mols         // channel: [ path(mols) ]
    ch_colabfold_db // channel: [ path(colabfold_db) ]
    ch_uniref30     // channel: [ path(uniref30) ]
    msa_server

    main:
    ch_samplesheet
        .branch { it ->
            fasta: it[1].extension == "fasta" || it[1].extension == "fa"
            yaml: it[1].extension == "yaml" || it[1].extension == "yml"
        }
        .set { ch_input_by_ext }

    ch_input_by_ext.fasta
        .set{ch_boltz_fasta_input}

    // Accept input FASTA and prepare input in Boltz YAML format
    BOLTZ_FASTA(ch_boltz_fasta_input)

    // Downstream operations are independent of original input type
    BOLTZ_FASTA.out.boltz_yaml
        .mix(ch_input_by_ext.yaml)
        .set { ch_boltz_yaml_input }

    if (!msa_server){
        BOLTZ_YAML_TO_COLABFOLD_FASTA(
            ch_boltz_yaml_input
        )

        MMSEQS_COLABFOLDSEARCH (
                BOLTZ_YAML_TO_COLABFOLD_FASTA.out.query_fasta,
                ch_colabfold_db,
                ch_uniref30
        )

        MMSEQS_COLABFOLDSEARCH.out.json
            .join(ch_boltz_yaml_input)
            .set { ch_split_msa_input }

        SPLIT_MSA(
            ch_split_msa_input
        )

        SPLIT_MSA.out.boltz_data.set { ch_boltz_input }

    }else{
        ch_boltz_yaml_input
            .map { meta, yaml -> [meta, yaml, []] }
            .set{ch_boltz_input}
    }

    RUN_BOLTZ(
        ch_boltz_input,
        ch_boltz_model,
        ch_boltz_ccd,
        ch_boltz2_aff,
        ch_boltz2_conf,
        ch_mols
    )

    RUN_BOLTZ
        .out
        .pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set {ch_pdb}

    RUN_BOLTZ
        .out
        .top_ranked_pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_top_ranked_pdb }

    RUN_BOLTZ
        .out
        .msa
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_msa }

    RUN_BOLTZ
        .out
        .pae
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_pae }

    RUN_BOLTZ
        .out
        .iptm
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_iptm }

    RUN_BOLTZ
        .out
        .ipsae
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_ipsae }

    RUN_BOLTZ
        .out
        .chainwise_iptm
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_chainwise_iptm }

    RUN_BOLTZ
        .out
        .chainwise_ipsae
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_chainwise_ipsae }

    // Hand MultiQC every metric this model actually produces, not just pLDDT.
    ch_multiqc_report = collectMultiqcMetrics("boltz", [
        RUN_BOLTZ.out.plddt,
        RUN_BOLTZ.out.msa,
        RUN_BOLTZ.out.ptm,
        RUN_BOLTZ.out.iptm,
        RUN_BOLTZ.out.pae
    ])

    emit:
    msa             = ch_msa
    confidence      = RUN_BOLTZ.out.confidence
    multiqc_report  = ch_multiqc_report
    top_ranked_pdb  = ch_top_ranked_pdb
    pdb             = ch_pdb
    pae             = ch_pae
    iptm            = ch_iptm
    ipsae           = ch_ipsae
    chainwise_iptm  = ch_chainwise_iptm
    chainwise_ipsae = ch_chainwise_ipsae
}
