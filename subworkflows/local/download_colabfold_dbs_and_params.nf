//
// Download all the required databases and params by Colabfold
//

include { DOWNLOAD_COLABFOLD_PARAMS; DOWNLOAD_UNIREF30; DOWNLOAD_COLABDB } from '../../modules/local/prepare_colabfold_dbs_and_params.nf'

workflow DOWNLOAD_COLABFOLD_DBS_AND_PARAMS {
	take:
	db

	main:
	ch_colabfold_params = DOWNLOAD_COLABFOLD_PARAMS(db).db_path
	ch_uniref30 = DOWNLOAD_UNIREF30(db).db_path
	ch_colabdb = DOWNLOAD_COLABDB(db).db_path
	download_path = ch_colabfold_params.combine(ch_uniref30, by: 0)
	.combine(ch_colabdb, by: 0).flatten().first()

	emit:
	download_path
}
