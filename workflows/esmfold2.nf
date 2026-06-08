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
//include { SPLIT_MSA } from '../modules/local/split_msa'
include { MMSEQS_COLABFOLDSEARCH } from '../modules/local/mmseqs_colabfoldsearch'
include { SPLIT_MSA as AF3_TO_ESMFOLD2 } from '../modules/local/af3_to_esmfold2' //TODO: fix this

//
// MODULE: ESMFOLD
//
include { RUN_ESMFOLD2 } from '../modules/local/run_esmfold2'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ESMFOLD2 {

    take:
    ch_samplesheet      // channel: samplesheet read from --input
    ch_versions         // channel: [ path(versions.yml) ]
    ch_esmfold2_model    // channel: [ path(esmfold_model) ]
    ch_colabfold_db     // channel: [ path(colabfold_db) ]
    ch_uniref30         // channel: [ path(uniref30) ]
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
    ch_versions = ch_versions.mix(BOLTZ_FASTA.out.versions)

    // Downstream operations are independent of original input type
    BOLTZ_FASTA.out.boltz_yaml
        .mix(ch_input_by_ext.yaml)
        .set { ch_boltz_yaml_input }

    if (params.esmfold2_use_msa) {
        BOLTZ_YAML_TO_COLABFOLD_FASTA(
            ch_boltz_yaml_input
        )
        ch_versions = ch_versions.mix(BOLTZ_YAML_TO_COLABFOLD_FASTA.out.versions)

        MMSEQS_COLABFOLDSEARCH (
                BOLTZ_YAML_TO_COLABFOLD_FASTA.out.query_fasta,
                ch_colabfold_db,
                ch_uniref30
        )
        ch_versions = ch_versions.mix(MMSEQS_COLABFOLDSEARCH.out.versions)

        MMSEQS_COLABFOLDSEARCH.out.json
            .join(ch_boltz_yaml_input)
            .set { ch_split_msa_input }

        AF3_TO_ESMFOLD2(
            ch_split_msa_input
        )
        ch_versions = ch_versions.mix(AF3_TO_ESMFOLD2.out.versions)

        AF3_TO_ESMFOLD2.out.boltz_data.set { ch_esmfold2_input }
    } else {
        //ch_dummy_msa_csv = Channel.value(file("${projectDir}/assets/NO_FILE"))
        //ch_boltz_yaml_input
        //    .combine(ch_dummy_msa_csv)
        //    .map { sample, dummy_msa_csv -> [ sample[0], sample[1], dummy_msa_csv ] }
        //    .set { ch_esmfold2_input }
        ch_boltz_yaml_input
            .map { meta, yaml -> [meta, yaml, []] }
            .set{ch_esmfold2_input}
    }

    RUN_ESMFOLD2(
        ch_esmfold2_input,
        ch_esmfold2_model
    )

    RUN_ESMFOLD2
        .out
        .cif
        .map { it ->
            def meta = it[0].clone();
            meta.model = "esmfold2"
            [ meta, it[1] ]
        }
        .set {ch_pdb}

    RUN_ESMFOLD2
        .out
        .top_ranked_pdb
        .map { it ->
            def meta = it[0].clone();
            meta.model = "esmfold2"
            [ meta, it[1] ]
        }
        .set { ch_top_ranked_pdb }

    RUN_ESMFOLD2
        .out
        .msa_raw
        .map { it ->
            def meta = it[0].clone();
            meta.model = "esmfold2"
            [ meta, it[1] ]
        }
        .set { ch_msa }

    RUN_ESMFOLD2
        .out
        .pae_raw
        .map { it ->
            def meta = it[0].clone();
            meta.model = "esmfold2"
            [ meta, it[1] ]
        }
        .set { ch_pae }

    RUN_ESMFOLD2
        .out
        .ptm_raw
        .map { it ->
            def meta = it[0].clone();
            meta.model = "esmfold2"
            [ meta, it[1] ]
        }
        .set { ch_ptm }

    RUN_ESMFOLD2
        .out
        .iptm_raw
        .map { it ->
            def meta = it[0].clone();
            meta.model = "esmfold2"
            [ meta, it[1] ]
        }
        .set { ch_iptm }

    RUN_ESMFOLD2
        .out
        .chainwise_iptm_raw
        .map { it ->
            def meta = it[0].clone();
            meta.model = "esmfold2"
            [ meta, it[1] ]
        }
        .set { ch_chainwise_iptm }

    /*
    RUN_ESMFOLD2
        .out
        .ipsae_raw
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_ipsae }

    RUN_ESMFOLD2
        .out
        .chainwise_ipsae_raw
        .map { it ->
            def meta = it[0].clone();
            meta.model = "boltz"
            [ meta, it[1] ]
        }
        .set { ch_chainwise_ipsae }

    RUN_ESMFOLD2
        .out
        .multiqc
        .map { it -> it[1] }
        .collect(sort: true)
        .map { it ->  [ [ "model": "boltz"], it.flatten() ] }
        .set { ch_multiqc_report  }
    */

    ch_versions       = ch_versions.mix(RUN_ESMFOLD2.out.versions)

    emit:
    versions        = ch_versions
    msa             = ch_msa
    //structures      = RUN_BOLTZ.out.structures
    //confidence      = RUN_BOLTZ.out.confidence
    multiqc_report  = channel.empty()
    top_ranked_pdb  = ch_top_ranked_pdb
    pdb             = ch_pdb
    pae             = ch_pae
    ptm             = ch_ptm
    iptm            = ch_iptm
    //ipsae           = ch_ipsae
    chainwise_iptm  = ch_chainwise_iptm
    //chainwise_ipsae = ch_chainwise_ipsae
}
