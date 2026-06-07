/*
 * Run Boltz
 */
process RUN_BOLTZ {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_boltz:2.0.0"

    input:
    tuple val(meta), path(yaml), path(files)
    path ('boltz1_conf.ckpt')
    path ('ccd.pkl')
    path ('boltz2_aff.ckpt')
    path ('boltz2_conf.ckpt')
    path ('mols')

    output:
    tuple val(meta), path ("boltz_results_${meta.id}")                        , optional: true, emit: intermediates
    tuple val(meta), path ("boltz_results_*/predictions/*/confidence*.json")  , emit: confidence
    tuple val(meta), path ("${meta.id}_plddt_mqc.tsv")                        , emit: multiqc
    tuple val(meta), path ("${meta.id}_boltz.cif")                            , emit: top_ranked_pdb
    tuple val(meta), path ("boltz_results_*/predictions/*/*.cif")             , emit: pdb
    tuple val(meta), path ("boltz_results_*/predictions/*/plddt_*model_0.npz"), emit: plddt
    tuple val(meta), path ("boltz_results_*/predictions/*/pae_*model_0.npz")  , emit: pae
    tuple val(meta), path ("${meta.id}_plddt_mqc.tsv")                        , emit: plddt_raw
    tuple val(meta), path ("${meta.id}_boltz_msa.tsv")                        , emit: msa_raw
    tuple val(meta), path ("${meta.id}_*_pae.tsv")                            , emit: pae_raw
    tuple val(meta), path ("${meta.id}_ptm.tsv")                              , emit: ptm_raw
    tuple val(meta), path ("${meta.id}_iptm.tsv")                             , optional: true, emit: iptm_raw
    tuple val(meta), path ("${meta.id}_ipsae.tsv")                            , optional: true, emit: ipsae_raw
    tuple val(meta), path ("${meta.id}_chainwise_ptm.tsv")                    , emit: summary_chainwise_ptm_raw
    tuple val(meta), path ("${meta.id}_chainwise_iptm.tsv")                   , optional: true, emit: chainwise_iptm_raw
    tuple val(meta), path ("${meta.id}_chainwise_ipsae.tsv")                  , optional: true, emit: chainwise_ipsae_raw
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

    # Temporary workaround to upstream boltz bug requiring redownload
    [ ! -f mols.tar ] && touch mols.tar

    # Staging user input from use_msa_server
    [ ! -f "${meta.id}.yaml" ] && cp "${yaml}" "${meta.id}.yaml"

    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L | grep -q "MIG"; then
        echo ">>> MIG mode detected. Mocking pynvml.nvmlDeviceGetNumGpuCores to avoid errors in Boltz. See https://github.com/nf-core/proteinfold/issues/417"
        boltz_wrapper.py predict "${meta.id}.yaml" ${args} --cache ./
    else
        boltz predict "${meta.id}.yaml" ${args} --cache ./
    fi

    cp boltz_results_*/predictions/${meta.id}/*_0.cif ./${meta.id}_boltz.cif

    # For consistency between server and local
    if compgen -G "boltz_results_${meta.id}/msa/${meta.id}*.csv" > /dev/null; then
        cp boltz_results_${meta.id}/msa/${meta.id}_*.csv ./
    fi

    extract_metrics.py --name ${meta.id} \\
        --structs boltz_results_*/predictions/${meta.id}/*.cif \\
        --jsons boltz_results_*/predictions/${meta.id}/confidence_*_model_*.json \\
        --npzs boltz_results_*/predictions/${meta.id}/pae_*_model_*.npz \\
        --csvs ${meta.id}_*.csv

    touch "${meta.id}_iptm.tsv" "${meta.id}_ipsae.tsv" "${meta.id}_chainwise_iptm.tsv" "${meta.id}_chainwise_ipsae.tsv"

    mv "${meta.id}_msa.tsv" "${meta.id}_boltz_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltz: \$(pip list | grep -i boltz | awk '{print \$2}' 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ./home
    export HOME=./home

    mkdir -p boltz_results_${meta.id}/predictions/${meta.id}/

    touch boltz_results_${meta.id}/predictions/${meta.id}/confidence_${meta.id}.json
    touch boltz_results_${meta.id}/predictions/${meta.id}/${meta.id}.cif
    touch boltz_results_${meta.id}/predictions/${meta.id}/plddt_${meta.id}_model_0.npz
    touch boltz_results_${meta.id}/predictions/${meta.id}/pae_${meta.id}_model_0.npz

    touch "${meta.id}_boltz.cif"
    touch "${meta.id}_plddt_mqc.tsv"
    touch "${meta.id}_boltz_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_ipsae.tsv"
    touch "${meta.id}_chainwise_ptm.tsv"
    touch "${meta.id}_chainwise_iptm.tsv"
    touch "${meta.id}_chainwise_ipsae.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltz: \$(pip list | grep -i boltz | awk '{print \$2}' 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
