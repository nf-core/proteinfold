/*
 * Run Boltz
 */
process RUN_BOLTZ {
    tag "$meta.id"
    label 'process_medium'

    container "fastfold/boltz-1:latest"
    
    input:
    tuple val(meta), path(fasta)
    path (files)
    path ('boltz1_conf.ckpt')
    path ('ccd.pkl')
    
    output:
    tuple val(meta), path ("boltz_results_*/processed/msa/*.npz"), emit: msa
    tuple val(meta), path ("boltz_results_*/processed/structures/*.npz"), emit: structures
    tuple val(meta), path ("boltz_results_*/predictions/*/confidence*.json"), emit: confidence
    tuple val(meta), path ("*"), emit: plddt
    tuple val(meta), path ("boltz_results_*/predictions/*/*.pdb"), emit: pdb
    path "versions.yml", emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''

    """
    boltz predict --output_format pdb ${args} "${fasta}" --cache ./
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
    stub:
    """
    mkdir -p boltz_results_${meta.id}/processed/msa/
    mkdir -p boltz_results_${meta.id}/processed/structures/
    mkdir -p boltz_results_${meta.id}/predictions/${meta.id}/
    
    touch boltz_results_${meta.id}/processed/msa/${meta.id}.npz
    touch boltz_results_${meta.id}/processed/structures/${meta.id}.npz
    touch boltz_results_${meta.id}/predictions/${meta.id}/confidence_${meta.id}.json
    touch boltz_results_${meta.id}/predictions/${meta.id}/${meta.id}.pdb
    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}