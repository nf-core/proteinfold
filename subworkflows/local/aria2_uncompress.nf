//
// Download with aria2 and uncompress the data if needed
//
include { UNTAR_TAR } from '../../modules/local/untar_tar'

include { UNTAR  } from '../../modules/nf-core/untar/main'
include { GUNZIP } from '../../modules/nf-core/gunzip/main'
include { ARIA2  } from '../../modules/local/aria2'


workflow ARIA2_UNCOMPRESS {
    take:
    source_url // url

    main:
    ARIA2 (
        source_url
    )
    ch_db = Channel.empty()

    if (source_url.endsWith('.tar')) {
        ch_db = UNTAR_TAR ( ARIA2.out.ch_db.map{ [ [:], it ] } ).untar.map{ it[1] }
    }else if (source_url.endsWith('.tar.gz')) {
        ch_db = UNTAR ( ARIA2.out.ch_db.flatten().map{ [ [:], it ] } ).untar.map{ it[1] }
    } else if (source_url.endsWith('.gz')) {
        ch_db = GUNZIP ( ARIA2.out.ch_db.flatten().map{ [ [:], it ] } ).gunzip.map { it[1] }
    }

    emit:
    db = ch_db //TODO
    // channel: [ val(meta), [ reads ] ]
    // versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

