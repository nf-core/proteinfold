/*
 * Run Boltz
 */
process RUN_BOLTZ {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_boltz:2.0.0"

    input:
    tuple val(meta), path(fasta), path(files)
    path ('boltz1_conf.ckpt')
    path ('ccd.pkl')
    path ('boltz2_aff.ckpt')
    path ('boltz2_conf.ckpt')
    path ('mols')

    output:
    tuple val(meta), path ("boltz_results_${meta.id}")                          , optional: true, emit: intermediates
    tuple val(meta), path ("boltz_results_*/processed/msa/*.npz")               , emit: msa_npz
    tuple val(meta), path ("boltz_results_*/predictions/*/plddt_*model_0.npz")  , emit: plddt_npz
    tuple val(meta), path ("boltz_results_*/processed/structures/*.npz")        , emit: structures_npz
    tuple val(meta), path ("boltz_results_*/predictions/*/confidence*.json")    , emit: confidence
    tuple val(meta), path ("${meta.id}_boltz.pdb")                              , emit: top_ranked_pdb
    tuple val(meta), path ("boltz_results_*/predictions/*/*.pdb")               , emit: pdb
    tuple val(meta), path ("boltz_results_*/predictions/*/pae_*model_0.npz")    , emit: pae_npz
    tuple val(meta), path ("${meta.id}_plddt.tsv")                              , emit: plddt
    tuple val(meta), path ("${meta.id}_msa.tsv")                                , emit: msa
    tuple val(meta), path ("${meta.id}_*_pae.tsv")                              , emit: pae
    tuple val(meta), path ("${meta.id}_ptm.tsv")                                , emit: ptm
    tuple val(meta), path ("${meta.id}_iptm.tsv")                               , optional: true, emit: iptm
    tuple val(meta), path ("${meta.id}_chainwise_ptm.tsv")                      , emit: chainwise_ptm
    tuple val(meta), path ("${meta.id}_chainwise_iptm.tsv")                     , optional: true, emit: chainwise_iptm
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_BOLTZ module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    """
    mkdir -p ./home
    export HOME=./home

    [ ! -f mols.tar ] && touch mols.tar

    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L | grep -q "MIG"; then
        echo ">>> MIG mode detected. Mocking pynvml.nvmlDeviceGetNumGpuCores to avoid errors in Boltz. See https://github.com/nf-core/proteinfold/issues/417"
        boltz_wrapper.py predict "${fasta}" --output_format "pdb" ${args} --cache ./
    else
        boltz predict "${fasta}" --output_format "pdb" ${args} --cache ./
    fi

    cp boltz_results_*/predictions/${meta.id}/*_0.pdb ./${meta.id}_boltz.pdb
    if [ -f boltz_results_*/msa/${meta.id}_0.csv ]; then
        cp boltz_results_*/msa/${meta.id}_*.csv ./
    fi

    extract_metrics.py --name ${meta.id} \\
        --structs boltz_results_*/predictions/${meta.id}/*.pdb \\
        --jsons boltz_results_*/predictions/${meta.id}/confidence_*_model_*.json \\
        --npzs boltz_results_*/predictions/${meta.id}/pae_*_model_*.npz \\
        --csvs ${meta.id}_*.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltz: \$(pip list | grep -i boltz | awk '{print \$2}' 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ./home
    export HOME=./home

    mkdir -p boltz_results_${meta.id}/processed/msa/
    mkdir -p boltz_results_${meta.id}/processed/structures/
    mkdir -p boltz_results_${meta.id}/predictions/${meta.id}/

    touch boltz_results_${meta.id}/processed/msa/${meta.id}.npz
    touch boltz_results_${meta.id}/processed/structures/${meta.id}.npz
    touch boltz_results_${meta.id}/predictions/${meta.id}/confidence_${meta.id}.json
    touch boltz_results_${meta.id}/predictions/${meta.id}/${meta.id}.pdb
    touch boltz_results_${meta.id}/predictions/${meta.id}/plddt_${meta.id}_model_0.npz
    touch boltz_results_${meta.id}/predictions/${meta.id}/pae_${meta.id}_model_0.npz

    touch "${meta.id}_boltz.pdb"
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_chainwise_ptm.tsv"
    touch "${meta.id}_chainwise_iptm.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltz: \$(pip list | grep -i boltz | awk '{print \$2}' 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
