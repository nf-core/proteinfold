//
// Download all the required databases and params by Colabfold
//

if (params.model_type == 'AlphaFold2-multimer-v1') {
    link_params = 'https://storage.googleapis.com/alphafold/alphafold_params_colab_2021-10-27.tar'
} else if (params.model_type == 'AlphaFold2-multimer-v2') {
    link_params = 'https://storage.googleapis.com/alphafold/alphafold_params_colab_2022-03-02.tar'
} else if (params.model_type == 'AlphaFold2-ptm') {
    link_params = 'https://storage.googleapis.com/alphafold/alphafold_params_colab_2022-03-02.tar'
}

colabfold_db = 'http://wwwuser.gwdg.de/~compbiol/colabfold/colabfold_envdb_202108.tar.gz'
uniref30     = 'http://wwwuser.gwdg.de/~compbiol/colabfold/uniref30_2103.tar.gz'

include { ARIA2_UNCOMPRESS as ARIA2_COLABFOLD_PARAMS                   } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_COLABFOLD_DB                       } from './aria2_uncompress'
include { ARIA2_UNCOMPRESS as ARIA2_UNIREF30                           } from './aria2_uncompress'
include { MMSEQS_TSV2EXPROFILEDB as MMSEQS_TSV2EXPROFILEDB_COLABFOLDDB } from '../../modules/local/mmseqs_tsv2exprofiledb'
include { MMSEQS_TSV2EXPROFILEDB as MMSEQS_TSV2EXPROFILEDB_UNIPROT30   } from '../../modules/local/mmseqs_tsv2exprofiledb'
include { MMSEQS_CREATEINDEX as MMSEQS_CREATEINDEX_COLABFOLDDB         } from '../../modules/local/mmseqs_createindex'
include { MMSEQS_CREATEINDEX as MMSEQS_CREATEINDEX_UNIPROT30           } from '../../modules/local/mmseqs_createindex'

workflow PREPARE_COLABFOLD_DBS {

	main:

    ch_params       = Channel.empty()
    ch_colabfold_db = Channel.empty()
    ch_uniref30     = Channel.empty()

    if (params.colabfold_db) {
        ch_params       = file( "${params.colabfold_db}/${params.model_type}" )
        if (params.mode == 'colabfold_local') {
            ch_colabfold_db = file( "${params.colabfold_db}/colabfold_envdb_202108_db" )
            ch_uniref30     = file( "${params.colabfold_db}/uniref30_2103_db" )
        }
    }
    else {
        ARIA2_COLABFOLD_PARAMS (
            link_params
        )
        ch_params = ARIA2_COLABFOLD_PARAMS.out.db

        if (params.mode == 'colabfold_local') {
            ARIA2_COLABFOLD_DB (
                colabfold_db
            )

            MMSEQS_TSV2EXPROFILEDB_COLABFOLDDB (
                ARIA2_COLABFOLD_DB.out.db
            )

            MMSEQS_CREATEINDEX_COLABFOLDDB (
                MMSEQS_TSV2EXPROFILEDB_COLABFOLDDB.out.db_exprofile
            )

            ARIA2_COLABFOLD_DB
                .out
                .db
                .combine(MMSEQS_TSV2EXPROFILEDB_COLABFOLDDB.out.db_exprofile)
                .combine (MMSEQS_CREATEINDEX_COLABFOLDDB.out.idx)
                .set { ch_colabfold_db }

            ARIA2_UNIREF30(
                uniref30
            )

            MMSEQS_TSV2EXPROFILEDB_UNIPROT30 (
                ARIA2_UNIREF30.out.db
            )

            MMSEQS_CREATEINDEX_UNIPROT30 (
                MMSEQS_TSV2EXPROFILEDB_UNIPROT30.out.db_exprofile
            )

            MMSEQS_TSV2EXPROFILEDB_UNIPROT30.out.db_exprofile
                .combine (MMSEQS_CREATEINDEX_UNIPROT30.out.idx)
                .set { ch_uniref30 }
        }
    }

	emit:
    params       = ch_params
    colabfold_db = ch_colabfold_db
    uniref30     = ch_uniref30
}
