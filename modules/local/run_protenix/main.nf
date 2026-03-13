/*
 * Run Protenix
 */
process RUN_PROTENIX {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nan5895/protenix:v1.0.6"

    input:
    tuple val(meta), path(input_json)
    path (files)
    path (model_weights)
    path (ccd_components)
    path (ccd_rdkit_mol)
    path (ccd_clusters)
    path (ccd_obsolete)

    output:
    tuple val(meta), path ("protenix_output")                                                          , optional: true, emit: intermediates
    tuple val(meta), path ("protenix_output/*/seed_*/predictions/*_summary_confidence_sample_*.json")  , emit: confidence
    tuple val(meta), path ("${meta.id}_plddt.tsv")                                                    , emit: multiqc
    tuple val(meta), path ("${meta.id}_protenix.pdb")                                                 , emit: top_ranked_pdb
    tuple val(meta), path ("protenix_output/*/seed_*/predictions/*_sample_*.cif")                     , emit: cif
    tuple val(meta), path ("${meta.id}_plddt.tsv")                                                    , emit: plddt_raw
    tuple val(meta), path ("${meta.id}_*_pae.tsv")                                                    , emit: pae_raw
    tuple val(meta), path ("${meta.id}_ptm.tsv")                                                      , emit: ptm_raw
    tuple val(meta), path ("${meta.id}_iptm.tsv")                                                     , optional: true, emit: iptm_raw
    tuple val(meta), path ("${meta.id}_chainwise_ptm.tsv")                                            , optional: true, emit: summary_chainwise_ptm_raw
    tuple val(meta), path ("${meta.id}_chainwise_iptm.tsv")                                           , optional: true, emit: chainwise_iptm_raw
    path "versions.yml"                                                                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_PROTENIX module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    def model_name = model_weights.baseName
    """
    export HOME=/tmp/home
    mkdir -p \${HOME}
    export CUDA_CACHE_DISABLE=1

    # Set up Protenix cache directory structure
    export PROTENIX_ROOT_DIR=./protenix_cache
    mkdir -p \${PROTENIX_ROOT_DIR}/checkpoint
    mkdir -p \${PROTENIX_ROOT_DIR}/common

    # Symlink downloaded files into expected locations
    ln -sf \$(realpath ${model_weights}) \${PROTENIX_ROOT_DIR}/checkpoint/${model_name}.pt
    ln -sf \$(realpath ${ccd_components}) \${PROTENIX_ROOT_DIR}/common/components.cif
    ln -sf \$(realpath ${ccd_rdkit_mol}) \${PROTENIX_ROOT_DIR}/common/components.cif.rdkit_mol.pkl
    ln -sf \$(realpath ${ccd_clusters}) \${PROTENIX_ROOT_DIR}/common/clusters-by-entity-40.txt
    ln -sf \$(realpath ${ccd_obsolete}) \${PROTENIX_ROOT_DIR}/common/obsolete_release_date.csv

    # Run Protenix prediction with JSON input from PROTENIX_FASTA
    protenix pred \\
        -i ${input_json} \\
        -o ./protenix_output \\
        -n ${model_name} \\
        -s 101 \\
        ${args}

    # Convert top-ranked CIF (sample_0) to PDB using gemmi
    BEST_CIF=\$(ls protenix_output/*/seed_*/predictions/*_sample_0.cif 2>/dev/null | head -1)
    if [ -n "\${BEST_CIF}" ]; then
        python3 -c "
import gemmi
doc = gemmi.cif.read('\${BEST_CIF}')
st = gemmi.make_structure_from_block(doc[0])
st.write_pdb('./${meta.id}_protenix.pdb')
"
    fi

    # Extract metrics from confidence JSON files
    protenix_extract_metrics.py --name ${meta.id} --out_dir ./protenix_output


    cat <<-EOF > versions.yml
    "${task.process}":
        protenix: \$(pip list | grep -i protenix | awk '{print \$2}' 2>/dev/null || echo "unknown")
EOF    
    """

    stub:
    """
    export HOME=/tmp/home
    mkdir -p \${HOME}
    export CUDA_CACHE_DISABLE=1

    mkdir -p protenix_output/${meta.id}/seed_101/predictions/

    touch protenix_output/${meta.id}/seed_101/predictions/${meta.id}_sample_0.cif
    touch protenix_output/${meta.id}/seed_101/predictions/${meta.id}_summary_confidence_sample_0.json

    touch "${meta.id}_protenix.pdb"
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_ptm.tsv"
    touch "${meta.id}_iptm.tsv"
    touch "${meta.id}_chainwise_ptm.tsv"
    touch "${meta.id}_chainwise_iptm.tsv"

    cat <<-EOF > versions.yml
    "${task.process}":
        protenix: \$(pip list | grep -i protenix | awk '{print \$2}' 2>/dev/null || echo "unknown")
EOF
      """
}
