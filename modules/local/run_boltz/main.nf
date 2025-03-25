/*
 * Run Boltz
 */
process RUN_BOLTZ {
    tag "$meta.id"
    label 'process_medium'

    container "docker://docker.io/nbtmsh/boltz:0.1.3"
    
    input:
    tuple val(meta), path(fasta)
    path ('boltz1_conf.ckpt')
    path ('ccd.pkl')
    
    output:
    tuple val(meta), path ("boltz_results_*/processed/msa/*.npz"), emit: msa
    tuple val(meta), path ("boltz_results_*/processed/structures/*.npz"), emit: structures
    tuple val(meta), path ("boltz_results_*/predictions/*/confidence*.json"), emit: confidence
    tuple val(meta), path ("*"), emit: plddt
    tuple val(meta), path ("boltz_results_*/predictions/*/*.pdb"), emit: pdb

    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''

    """
    boltz predict --output_format pdb ${args} "${fasta}" --cache ./
    """
}
