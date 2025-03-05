/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { RUN_ROSETTAFOLD2NA } from '../modules/local/run_rosettafold2na.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW: ROSETTAFOLD2NA
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ROSETTAFOLD2NA {

    take:
        ch_samplesheet
        ch_versions             // channel: [ path(versions.yml) ]
        ch_uniref30             // channel: files from UniRef30 (e.g., UniRef30_2020_06/*)
        ch_bfd                  // channel: files from BFD (e.g., bfd/*)
        ch_pdb100               // channel: files from pdb100 (e.g., pdb100_2021Mar03/*)
        ch_weights              // channel: RF2NA weights file
        ch_rfam_cm              // channel: Rfam CM files
        ch_rnac                 // channel: RNAcentral processed files
        ch_rnacentral_blast     // channel: RNAcentral BLAST database
        ch_nt                   // channel: NT database
        ch_dummy_file

    main:
        ch_multiqc_files    = Channel.empty()
        ch_pdb              = Channel.empty()
        ch_top_ranked_pdb   = Channel.empty()
        ch_msa              = Channel.empty()
        ch_multiqc_report   = Channel.empty()

        // Log the received database paths for debugging
        log.info "RosettaFold2NA received the following database paths:"
        log.info "UniRef30: ${ch_uniref30}"
        log.info "BFD: ${ch_bfd}"
        log.info "PDB100: ${ch_pdb100}"
        log.info "Weights: ${ch_weights}"
        log.info "Rfam CM: ${ch_rfam_cm}"
        log.info "RNAcentral: ${ch_rnac}"
        log.info "RNAcentral BLAST: ${ch_rnacentral_blast}"
        log.info "NT: ${ch_nt}"

        // Invoke the RF2NA process with channels in the order defined by its input block
        RUN_ROSETTAFOLD2NA (
            ch_samplesheet,
            ch_uniref30,
            ch_bfd,
            ch_pdb100,
            ch_weights,
            ch_rfam_cm,
            ch_rnac,
            ch_rnacentral_blast,
            ch_nt
        )

        // Process the PDB output: combine with a dummy file and set the model tag to "rosettafold2na"
        RUN_ROSETTAFOLD2NA.out.pdb
            .combine(ch_dummy_file)
            .map { meta, pdb, dummy ->
                meta.model = "rosettafold2na"
                [meta, pdb, dummy]
            }
            .set { ch_pdb_msa }

        // Map the processed channel to produce top-ranked PDB output (using meta.id)
        ch_pdb_msa
            .map { meta, pdb, dummy -> [meta.id, meta, pdb, dummy] }
            .set { ch_top_ranked_pdb }

        // Process the MultiQC output:
        RUN_ROSETTAFOLD2NA.out.multiqc
            .map { it[1] }
            .toSortedList()
            .map { [[model: "rosettafold2na"], it.flatten()] }
            .set { ch_multiqc_report }

        // Merge version information
        ch_versions = ch_versions.mix(RUN_ROSETTAFOLD2NA.out.versions)

    emit:
        pdb_msa        = ch_pdb_msa        // channel: [ meta, <PDB file>, dummy ]
        top_ranked_pdb = ch_top_ranked_pdb // channel: [ id, meta, <PDB file>, dummy ]
        multiqc_report = ch_multiqc_report // channel: MultiQC report files
        versions       = ch_versions       // channel: [ versions.yml ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/