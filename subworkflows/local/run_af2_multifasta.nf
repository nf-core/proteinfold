//
// Check input samplesheet and get read channels
//

include { SPLIT_MULTI_FASTA } from '../../modules/local/split_multifasta.nf'
include { RUN_AF2 } from '../../modules/local/af2.nf'


workflow RUN_AF2_MULTIFASTA {
    take:
    input // file: fasta input

    main:
    //TODO function to test for multi-fasta
    SPLIT_MULTI_FASTA(input)
    RUN_AF2(SPLIT_MULTI_FASTA.out.map{ it -> [it.baseName,it]})
}
