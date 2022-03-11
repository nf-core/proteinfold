process RUN_AF2 {
	tag "${seq_name}"
	label 'customConf'

//TODO
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        		'docker://athbaltzis/af2_proteinfold:v0.3' :
				'docker://athbaltzis/af2_proteinfold:v0.3' }"

	input:
	tuple val(seq_name), path(fasta)
    val   max_template_date
	val   db_preset
	val   model_preset
	val   gpu_relax

	output:
	path ("*")

	script:
	if (db_preset == "full_dbs") {
	"""
	python3 /app/alphafold/run_alphafold.py \
	--fasta_paths=${fasta} \
	--max_template_date=${max_template_date} \
	--model_preset=${model_preset} \
	--db_preset=${db_preset} \
	--output_dir=\$PWD \
	--data_dir=/db/ \
	--uniref90_database_path=/db/uniref90/uniref90.fasta \
	--mgnify_database_path=/db/mgnify/mgy_clusters.fa \
	--bfd_database_path=/db/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
	--uniclust30_database_path=/db/uniclust30/uniclust30_2018_08/uniclust30_2018_08 \
	--pdb70_database_path=/db/pdb70/pdb70 \
	--template_mmcif_dir=/db/pdb_mmcif/mmcif_files \
	--obsolete_pdbs_path=/db/pdb_mmcif/obsolete.dat \
	--use_gpu_relax=${gpu_relax}
	cp "${fasta.baseName}"/ranked_0.pdb ./"${fasta.baseName}".alphafold.pdb
	"""
	}
	else if (db_preset == "reduced_dbs") {
	"""
	python3 /app/alphafold/run_alphafold.py \
	--fasta_paths=${fasta} \
	--max_template_date=${max_template_date} \
	--model_preset=${model_preset} \
	--db_preset=${db_preset} \
	--output_dir=\$PWD \
	--data_dir=/db/ \
	--uniref90_database_path=/db/uniref90/uniref90.fasta \
	--mgnify_database_path=/db/mgnify/mgy_clusters.fa \
	--small_bfd_database_path=/db/small_bfd/bfd-first_non_consensus_sequences.fasta \
	--uniclust30_database_path=/db/uniclust30/uniclust30_2018_08/uniclust30_2018_08 \
	--pdb70_database_path=/db/pdb70/pdb70 \
	--template_mmcif_dir=/db/pdb_mmcif/mmcif_files \
	--obsolete_pdbs_path=/db/pdb_mmcif/obsolete.dat
	cp "${fasta.baseName}"/ranked_0.pdb ./"${fasta.baseName}".alphafold.pdb
	"""
	}
}
