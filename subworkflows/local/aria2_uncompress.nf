//
// Download with aria2 and uncompress the data if needed
//

include { ARIA2            } from '../../modules/local/aria2'
include { GUNZIP           } from '../../modules/nf-core/modules/gunzip/main'
include { UNTAR            } from '../../modules/nf-core/modules/untar/main'
include { UNTAR as UNTAR_AF2_PARAMS } from '../../modules/local/untar'
include { UNTAR as UNTAR_PDB70      } from '../../modules/local/untar'

workflow ARIA2_UNCOMPRESS {
    take:
    source_url // url

    main:
    ARIA2 (
        source_url
    )
    ch_db = Channel.empty()

    if (source_url.contains('pdb70')) {
	ch_db = UNTAR_PDB70 ( ARIA2.out.ch_db ).untar
    } else if (source_url.endsWith('.gz')) {
        ch_db = GUNZIP ( ARIA2.out.ch_db.flatten().map{ [ [:], it ] } ).gunzip.map { it[1] }
    } else if (source_url.endsWith('tar.gz')) {
        ch_db = UNTAR ( ARIA2.out.ch_db.flatten().map{ [ [:], it ] } ).untar.map{ it[1] }
    } else if (source_url.endsWith('tar')) {
        ch_db = UNTAR_AF2_PARAMS ( ARIA2.out.ch_db ).untar
    }

    emit:
    db = ch_db
    // channel: [ val(meta), [ reads ] ]
    // versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

