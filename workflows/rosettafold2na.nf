workflow ROSETTAFOLD2NA {

    take:
    ch_samplesheet
    ch_versions
    ch_uniref30
    ch_bfd
    ch_pdb100
    ch_rna
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
    log.info "RNA: ${ch_rna}"

    RUN_ROSETTAFOLD2NA (
        ch_samplesheet,
        ch_uniref30,
        ch_bfd,
        ch_pdb100,
        ch_rna
    )

    RUN_ROSETTAFOLD2NA.out.pdb
        .combine(ch_dummy_file)
        .map { meta, pdb, dummy ->
            meta.model = "rosettafold2na"
            [meta, pdb, dummy]
        }
        .set { ch_pdb_msa }

    ch_pdb_msa
        .map { meta, pdb, dummy -> [meta.id, meta, pdb, dummy] }
        .set { ch_top_ranked_pdb }

    RUN_ROSETTAFOLD2NA.out.multiqc
        .map { it[1] }
        .toSortedList()
        .map { [[model: "rosettafold2na"], it.flatten()] }
        .set { ch_multiqc_report }

    ch_versions = ch_versions.mix(RUN_ROSETTAFOLD2NA.out.versions)

    emit:
    pdb_msa        = ch_pdb_msa
    top_ranked_pdb = ch_top_ranked_pdb
    multiqc_report = ch_multiqc_report
    versions       = ch_versions
}