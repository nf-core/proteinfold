//
// Download all the required databases and params by Colabfold
//
include { MMSEQS_CREATEINDEX as MMSEQS_CREATEINDEX_COLABFOLDDB } from '../../modules/nf-core/mmseqs/createindex/main'
include { MMSEQS_CREATEINDEX as MMSEQS_CREATEINDEX_UNIPROT30   } from '../../modules/nf-core/mmseqs/createindex/main'

include { ARIA2_UNCOMPRESS as ARIA2_COLABFOLD_PARAMS } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_COLABFOLD_DB     } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_UNIREF30         } from './aria2_uncompress'

workflow PREPARE_COLABFOLD_DBS {

    take:
    colabfold_db                     // directory: path/to/colabfold/DBs and params
    use_msa_server                   //      bool: Specifies whether to use web msa server
    colabfold_alphafold2_params_path // directory: /path/to/colabfold/alphafold2/params/
    colabfold_envdb_path             // directory: /path/to/colabfold/db/
    colabfold_uniref30_path          // directory: /path/to/uniref30/colabfold/
    colabfold_alphafold2_params_link //    string: Specifies the link to download colabfold alphafold2 params
    colabfold_db_link                //    string: Specifies the link to download colabfold db
    colabfold_uniref30_link          //    string: Specifies the link to download uniref30
    colabfold_create_index           //   boolean: Create index for colabfold db

    main:
    ch_params       = channel.empty()
    ch_colabfold_db = channel.empty()
    ch_uniref30     = channel.empty()
    ch_versions     = channel.empty()

    if (colabfold_db) {
        ch_params = channel.value(file(colabfold_alphafold2_params_path, type: 'any'))
        if (!use_msa_server) {
            ch_colabfold_db = channel.value(file(colabfold_envdb_path, type: 'any'))
            ch_uniref30     = channel.value(file(colabfold_uniref30_path, type: 'any'))
        }
    }
    else {
        ARIA2_COLABFOLD_PARAMS (
            colabfold_alphafold2_params_link
        )
        ch_params = ARIA2_COLABFOLD_PARAMS
                        .out
                        .db
                        .map { dir -> dir.listFiles().findAll { it -> it.isFile() } }

        ch_versions = ch_versions.mix(ARIA2_COLABFOLD_PARAMS.out.versions)

        if (!use_msa_server) {
            ARIA2_COLABFOLD_DB (
                colabfold_db_link
            )
            ch_versions = ch_versions.mix(ARIA2_COLABFOLD_DB.out.versions)

            ch_colabfold_db = ARIA2_COLABFOLD_DB.out.db

            if (colabfold_create_index) {
                MMSEQS_CREATEINDEX_COLABFOLDDB (
                    ch_colabfold_db
                        .map { path_str ->
                            def db_file = file(path_str)
                            [ [id: 'colabfolddb'], db_file ]
                        }
                )
                ch_colabfold_db = MMSEQS_CREATEINDEX_COLABFOLDDB
                                    .out
                                    .db_indexed
                                    .map { meta, dir ->
                                        file("${dir}/*")
                                    }
                ch_versions = ch_versions.mix(MMSEQS_CREATEINDEX_COLABFOLDDB.out.versions)

            } else {
                ch_colabfold_db = ch_colabfold_db
                                    .map { dir_path ->
                                        file("${dir_path}/*")
                                    }
            }

            ARIA2_UNIREF30(
                colabfold_uniref30_link
            )
            ch_versions = ch_versions.mix(ARIA2_UNIREF30.out.versions)

            ch_uniref30 = ARIA2_UNIREF30.out.db

            if (colabfold_create_index) {
                MMSEQS_CREATEINDEX_UNIPROT30 (
                    ch_uniref30
                        .map { path_str ->
                            def db_file = file(path_str)
                            [ [id: 'uniprot30'], db_file ]
                        }
                )
                ch_uniref30 = MMSEQS_CREATEINDEX_UNIPROT30
                                .out
                                .db_indexed
                                .map { meta, dir ->
                                    file("${dir}/*")
                                }
                ch_versions = ch_versions.mix(MMSEQS_CREATEINDEX_UNIPROT30.out.versions)

            } else {
                ch_uniref30 = ch_uniref30
                                .map { dir_path ->
                                    file("${dir_path}/*")
                                }
            }
        }
    }

    emit:
    params       = ch_params
    colabfold_db = ch_colabfold_db
    uniref30     = ch_uniref30
    versions     = ch_versions
}
