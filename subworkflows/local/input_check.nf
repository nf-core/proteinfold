//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fasta_channel(it) }
        .set { fastas }

    emit:
    fastas                                    // channel: [ val(meta), [ fastas ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ fasta ] ]
def create_fasta_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id      = row.sequence

    // add path of the fasta file to the meta map
    def fasta_meta = []
    if (!file(row.fasta).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Fasta file does not exist!\n${row.fasta}"
    }
    fasta_meta = [ meta, file(row.fasta) ]

    return fasta_meta
}
