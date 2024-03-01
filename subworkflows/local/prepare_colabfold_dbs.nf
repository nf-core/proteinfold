//
// Download all the required databases and params by Colabfold
//
include { MMSEQS_CREATEINDEX as MMSEQS_CREATEINDEX_COLABFOLDDB         } from '../../modules/nf-core/mmseqs/createindex/main'
include { MMSEQS_CREATEINDEX as MMSEQS_CREATEINDEX_UNIPROT30           } from '../../modules/nf-core/mmseqs/createindex/main'

include { ARIA2_UNCOMPRESS as ARIA2_COLABFOLD_PARAMS                   } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_COLABFOLD_DB                       } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_UNIREF30                           } from './aria2_uncompress'
include { MMSEQS_TSV2EXPROFILEDB as MMSEQS_TSV2EXPROFILEDB_COLABFOLDDB } from '../../modules/nf-core/mmseqs/tsv2exprofiledb/main'
include { MMSEQS_TSV2EXPROFILEDB as MMSEQS_TSV2EXPROFILEDB_UNIPROT30   } from '../../modules/nf-core/mmseqs/tsv2exprofiledb/main'

workflow PREPARE_COLABFOLD_DBS {

    take:
    colabfold_db                     // directory: path/to/colabfold/DBs and params
    colabfold_server                 // string: Specifies the server to use for colabfold
    colabfold_alphafold2_params_path // directory: /path/to/colabfold/alphafold2/params/
    colabfold_db_path                // directory: /path/to/colabfold/db/
    uniref30_colabfold_path          // directory: /path/to/uniref30/colabfold/
    colabfold_alphafold2_params      //    string: Specifies the link to download colabfold alphafold2 params
    colabfold_db_link                //    string: Specifies the link to download colabfold db
    uniref30_colabfold_link          //    string: Specifies the link to download uniref30
    create_colabfold_index           //   boolean: Create index for colabfold db

    main:
    ch_params       = Channel.empty()
    ch_colabfold_db = Channel.empty()
    ch_uniref30     = Channel.empty()
    ch_versions     = Channel.empty()

    if (colabfold_db) {
        ch_params = file( colabfold_alphafold2_params_path, type: 'any' )
        if (colabfold_server == 'local') {
            ch_colabfold_db = file( colabfold_db_path, type: 'any' )
            ch_uniref30     = file( uniref30_colabfold_path , type: 'any' )
        }
    }
    else {
        ARIA2_COLABFOLD_PARAMS (
            colabfold_alphafold2_params
        )
        ch_params = ARIA2_COLABFOLD_PARAMS.out.db
        ch_versions = ch_versions.mix(ARIA2_COLABFOLD_PARAMS.out.versions)

        if (params.colabfold_server == 'local') {
            ARIA2_COLABFOLD_DB (
                colabfold_db_link
            )
            ch_versions = ch_versions.mix(ARIA2_COLABFOLD_DB.out.versions)

            MMSEQS_TSV2EXPROFILEDB_COLABFOLDDB (
                ARIA2_COLABFOLD_DB.out.db
            )
            ch_colabfold_db = MMSEQS_TSV2EXPROFILEDB_COLABFOLDDB.out.db_exprofile
            ch_versions = ch_versions.mix(MMSEQS_TSV2EXPROFILEDB_COLABFOLDDB.out.versions)

            if (params.create_colabfold_index) {
                MMSEQS_CREATEINDEX_COLABFOLDDB (
                    MMSEQS_TSV2EXPROFILEDB_COLABFOLDDB.out.db_exprofile
                )
                ch_colabfold_db = MMSEQS_CREATEINDEX_COLABFOLDDB.out.db_index
                ch_versions = ch_versions.mix(MMSEQS_CREATEINDEX_COLABFOLDDB.out.versions)
            }

            ARIA2_UNIREF30(
                uniref30_colabfold_link
            )
            ch_versions = ch_versions.mix(ARIA2_UNIREF30.out.versions)

            MMSEQS_TSV2EXPROFILEDB_UNIPROT30 (
                ARIA2_UNIREF30.out.db
            )
            ch_uniref30 = MMSEQS_TSV2EXPROFILEDB_UNIPROT30.out.db_exprofile
            ch_versions = ch_versions.mix(MMSEQS_TSV2EXPROFILEDB_UNIPROT30.out.versions)

            if (create_colabfold_index) {
                MMSEQS_CREATEINDEX_UNIPROT30 (
                    MMSEQS_TSV2EXPROFILEDB_UNIPROT30.out.db_exprofile
                )
                ch_uniref30 = MMSEQS_CREATEINDEX_UNIPROT30.out.db_index
                ch_versions = ch_versions.mix(MMSEQS_CREATEINDEX_UNIPROT30.out.versions)
            }
        }
    }

    emit:
    params       = ch_params
    colabfold_db = ch_colabfold_db
    uniref30     = ch_uniref30
    versions     = ch_versions
}
