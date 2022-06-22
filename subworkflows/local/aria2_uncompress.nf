//
// Download with aria2 and uncompress the data if needed
//

include { ARIA2  } from '../../modules/local/aria2'
include { UNTAR  } from '../../modules/local/untar'
include { GUNZIP } from '../../modules/nf-core/modules/gunzip/main'

workflow ARIA2_UNCOMPRESS {
    take:
    source_url // url
    // output_dir // directory to place the downloaded data

    main:
    ARIA2 (
        source_url
    )
    ch_db = Channel.empty()
    // ARIA2.out.ch_db.view()
    if (source_url.endsWith('tar.gz') || source_url.endsWith('tar')) {
        ch_db = UNTAR ( ARIA2.out.ch_db.flatten().map{ [ [:], it ] } ).untar.map{ it[1] }
    } else if (source_url.endsWith('.gz')) {
        ch_db = GUNZIP ( ARIA2.out.ch_db.flatten().map{ [ [:], it ] } ).gunzip.map { it[1] }
    }

    emit:
    db = ch_db
    // channel: [ val(meta), [ reads ] ]
    // versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}
