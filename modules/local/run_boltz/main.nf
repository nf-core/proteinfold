/*
 * Run Boltz
 */
process RUN_BOLTZ {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_boltz:dev"

    input:
    tuple val(meta), path(fasta)
    path (files)
    path ('boltz1_conf.ckpt')
    path ('ccd.pkl')

    output:
    tuple val(meta), path ("boltz_results_*/processed/msa/*.npz")               , emit: msa
    tuple val(meta), path ("boltz_results_*/processed/structures/*.npz")        , emit: structures
    tuple val(meta), path ("boltz_results_*/predictions/*/confidence*.json")    , emit: confidence
    tuple val(meta), path ("${meta.id}_plddt_mqc.tsv")                          , emit: multiqc
    tuple val(meta), path ("*boltz.pdb")                                        , emit: pdb
    tuple val(meta), path ("boltz_results_*/predictions/*/plddt_*model_0.npz")  , emit: plddt
    tuple val(meta), path ("boltz_results_*/predictions/*/pae_*model_0.npz")    , emit: pae

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_BOLTZ module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def version = "0.4.1"
    def args = task.ext.args ?: ''

    """
    boltz predict "${fasta}" ${args} --cache ./ --write_full_pae --output_format pdb
    cp boltz_results_*/predictions/*/*.pdb ./${meta.id}_boltz.pdb

    echo -e Atom_serial_number"\\t"Atom_name"\\t"Residue_name"\\t"Residue_sequence_number"\\t"pLDDT > ${meta.id}_plddt_mqc.tsv
    awk '{print \$2"\\t"\$3"\\t"\$4"\\t"\$6"\\t"\$11}' boltz_results_*/predictions/*/*.pdb | grep -v 'N/A' | uniq >> ${meta.id}_plddt_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltz: $version
    END_VERSIONS
    """

    stub:
    def version = "0.4.1"
    """
    mkdir -p boltz_results_${meta.id}/processed/msa/
    mkdir -p boltz_results_${meta.id}/processed/structures/
    mkdir -p boltz_results_${meta.id}/predictions/${meta.id}/

    touch ${meta.id}_boltz.pdb
    touch boltz_results_${meta.id}/processed/msa/${meta.id}.npz
    touch boltz_results_${meta.id}/processed/structures/${meta.id}.npz
    touch boltz_results_${meta.id}/predictions/${meta.id}/confidence_${meta.id}.json
    touch boltz_results_${meta.id}/predictions/${meta.id}/${meta.id}.pdb
    touch boltz_results_${meta.id}/predictions/${meta.id}/plddt_${meta.id}_model_0.npz
    touch boltz_results_${meta.id}/predictions/${meta.id}/pae_${meta.id}_model_0.npz
    touch ${meta.id}_plddt_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltz: $version
    END_VERSIONS
    """
}
