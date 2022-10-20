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
// def create_fasta_channel(LinkedHashMap row) {
//     // create meta map
//     def meta = [:]
//     // meta.sequence      = row.sequence
//     meta.id      = row.sequence
//     // meta.fasta   = row.fasta

//     // add path of the fasta file to the meta map
//     def fasta_meta = []
//     if (!file(row.fasta).exists()) {
//         exit 1, "ERROR: Please check input samplesheet -> Fasta file does not exist!\n${row.fasta}"
//     }
//     fasta_meta = [ meta, file(row.fasta) ]

//     return fasta_meta
// }

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.sequence      = row.sequence
    meta.fasta   = row.fasta
    array = [ meta, file(row.fasta) ]
    /*def array = []
    if (!file(row.fastq_1).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.fastq_1}"
    }
    if (meta.single_end) {
        fastq_meta = [ meta, [ file(row.fastq_1) ] ]
    } else {
        if (!file(row.fastq_2).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${row.fastq_2}"
        }
        array = [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
    }*/
    return array
}
