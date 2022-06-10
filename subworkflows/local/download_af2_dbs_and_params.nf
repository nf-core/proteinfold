//
// Download all the required databases and params by AlphaFold2
//

include { DOWNLOAD_AF2_PARAMS; DOWNLOAD_SMALL_BFD; DOWNLOAD_BFD; DOWNLOAD_MGNIFY; DOWNLOAD_PDB70; DOWNLOAD_PDB_MMCIF; DOWNLOAD_UNICLUST30; DOWNLOAD_UNIREF90; DOWNLOAD_UNIPROT } from '../../modules/local/prepare_af2_dbs_and_params.nf'

workflow DOWNLOAD_AF2_DBS_AND_PARAMS {
	take:
	db
	full_dbs

	main:
	if (full_dbs == true) {
		ch_af2_params = DOWNLOAD_AF2_PARAMS(db).db_path
		ch_bfd = DOWNLOAD_BFD(db).db_path
		ch_mgnify = DOWNLOAD_MGNIFY(db).db_path
		ch_pdb70 = DOWNLOAD_PDB70(db).db_path
		ch_pdb_mmcif = DOWNLOAD_PDB_MMCIF(db).db_path
		ch_uniclust30 = DOWNLOAD_UNICLUST30(db).db_path
		ch_uniref90 = DOWNLOAD_UNIREF90(db).db_path
		ch_uniprot = DOWNLOAD_UNIPROT(db).db_path
		download_path = ch_af2_params.combine(ch_bfd, by: 0)
		.combine(ch_mgnify, by: 0)
		.combine(ch_pdb70, by: 0)
		.combine(ch_pdb_mmcif, by: 0)
		.combine(ch_uniclust30, by: 0)
		.combine(ch_uniref90, by: 0)
		.combine(ch_uniprot, by: 0)
	} else {
		ch_af2_params = DOWNLOAD_AF2_PARAMS(db).db_path
		ch_small_bfd = DOWNLOAD_SMALL_BFD(db).db_path
		ch_mgnify = DOWNLOAD_MGNIFY(db).db_path
		ch_pdb70 = DOWNLOAD_PDB70(db).db_path
		ch_pdb_mmcif = DOWNLOAD_PDB_MMCIF(db).db_path
		ch_uniclust30 = DOWNLOAD_UNICLUST30(db).db_path
		ch_uniref90 = DOWNLOAD_UNIREF90(db).db_path
		ch_uniprot = DOWNLOAD_UNIPROT(db).db_path
		download_path = ch_af2_params.combine(ch_small_bfd, by: 0)
		.combine(ch_mgnify, by: 0)
		.combine(ch_pdb70, by: 0)
		.combine(ch_pdb_mmcif, by: 0)
		.combine(ch_uniclust30, by: 0)
		.combine(ch_uniref90, by: 0)
		.combine(ch_uniprot, by: 0).flatten().first()
	}

	emit:
	download_path
}
