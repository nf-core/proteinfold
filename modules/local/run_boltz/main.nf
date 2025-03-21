/*
 * Run Boltz
 */
process RUN_BOLTZ {
    tag "$meta.id"
    label 'process_medium'

    container "/srv/scratch/sbf-pipelines/proteinfold/singularity/boltz.sif"
    
    input:
    tuple val(meta), path(fasta)
    path ('boltz1_conf.ckpt')
    path ('ccd.pkl')
    
    output:
    path ("boltz_results_*/processed/msa/*.npz"), emit: msa
    path ("boltz_results_*/processed/structures/*.npz"), emit: structures
    path ("boltz_results_*/predictions/*/confidence*.json"), emit: confidence
    path ("*"), emit: plddt
    path ("boltz_results_*/predictions/*/*.pdb"), emit: pdb
    
    script:
    """
    boltz predict --output_format pdb --use_msa_server "./${fasta.name}" --cache ./
    """
}
