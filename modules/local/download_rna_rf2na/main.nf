process DOWNLOAD_RNA_DATABASES {
    tag "Download and process RNA databases"
    label 'process_medium'

    container "quay.io/nf-core/proteinfold_rosettafold2na:2.0.0"

    input:
    val rfam_full_region_link
    val rfam_cm_link
    val rnacentral_rfam_annotations_link
    val rnacentral_id_mapping_link
    val rnacentral_sequences_link

    output:
    path "RNA", emit: ch_db
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("DOWNLOAD_RNA_DATABASES module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    """
    mkdir -p RNA
    cd RNA

    # Download and process Rfam
    wget -O Rfam.full_region.gz ${rfam_full_region_link}
    wget -O Rfam.cm.gz ${rfam_cm_link}
    gunzip Rfam.full_region.gz
    gunzip Rfam.cm.gz
    cmpress Rfam.cm

    # Download and process RNAcentral
    wget -O id_mapping.tsv.gz ${rnacentral_id_mapping_link}
    wget -O rfam_annotations.tsv.gz ${rnacentral_rfam_annotations_link}
    wget -O rnacentral_sequences.fasta.gz ${rnacentral_sequences_link}

    # Use the reprocess_rnac.pl script from the RoseTTAFold2NA repository
    /app/RoseTTAFold2NA/input_prep/reprocess_rnac.pl id_mapping.tsv.gz rfam_annotations.tsv.gz

    gunzip -c rnacentral_sequences.fasta.gz | makeblastdb -in - -dbtype nucl -parse_seqids -out rnacentral.fasta -title "RNACentral"

    # Download nt database
    update_blastdb.pl --decompress nt

    cd ..

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cmpress: \$(cmpress -h | grep -oP 'INFERNAL \\K\\d+\\.\\d+')
        makeblastdb: \$(makeblastdb -version | grep -oP 'makeblastdb: \\K\\d+\\.\\d+\\.\\d+')
        update_blastdb: \$(update_blastdb.pl --version | grep -oP 'Update BLAST databases \\K\\d+\\.\\d+\\.\\d+')
        perl: \$(perl --version | grep -oP 'This is perl.*\\K\\d+\\.\\d+\\.\\d+')
        rf2na: \$(grep "version" /app/RoseTTAFold2NA/README.md | awk '{print \$2}')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p RNA
    touch RNA/Rfam.full_region RNA/Rfam.cm RNA/id_mapping.tsv RNA/rfam_annotations.tsv RNA/rnacentral.fasta
    touch RNA/nt.00.nhr RNA/nt.00.nin RNA/nt.00.nsq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cmpress: 1.1.4
        makeblastdb: 2.12.0
        update_blastdb: 2.12.0
        perl: 5.32.1
        rf2na: 1.0.0
    END_VERSIONS
    """
}
