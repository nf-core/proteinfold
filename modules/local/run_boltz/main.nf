/*
 * Run Alphafold2
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
    path ("boltz_results_*/predictions/*/plddt_*.npz"), emit: plddt
    
    script:
    """
    boltz predict --use_msa_server "./${fasta.name}" --cache ./
    """
}
