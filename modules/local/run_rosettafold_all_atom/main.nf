/*
 * Run RoseTTAFold_All_Atom
 */
process RUN_ROSETTAFOLD_ALL_ATOM {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_rosettafold_all_atom:2.0.0"

    input:
    tuple val(meta), path(yaml)
    val uniref30_prefix
    path ('bfd/*')
    path ('uniref30/*')
    path ('pdb100_2021Mar03/*')
    path ('RFAA_paper_weights.pt')
    path (fasta_files)

    output:
    path ("raw/**")                                                     , emit: raw
    tuple val(meta), path ("${meta.id}_rosettafold_all_atom.pdb")       , emit: pdb
    tuple val(meta), path ("${meta.id}_plddt.tsv")                      , emit: multiqc
    tuple val(meta), path ("${meta.id}_rosettafold_all_atom_msa.tsv")   , emit: msa
    // I think there should always be PAE from the .pt PyTorch model. extract_metrics.py has condition import torch to handle this
    tuple val(meta), path ("${meta.id}_*_pae.tsv")                      , emit: paes
    tuple val(meta), path ("${meta.id}_0_pae.tsv")                      , emit: pae
    path "versions.yml"                                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when


    // TODO: I'm not convinced --a3ms to chain /A/msa is entirely what I want here, but the MSA isn't easily stored elsewhere
    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ROSETTAFOLD_ALL_ATOM module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    """
    export DB_UR30="uniref30/${uniref30_prefix}"
    mamba run --name RFAA python /app/RoseTTAFold-All-Atom/rf2aa/run_inference.py \\
        --config-dir /app/RoseTTAFold-All-Atom/rf2aa/config/inference \\
        --config-name "${yaml}" $args

    # Temporary hack - maybe better to sanitize YAML - job_name -> meta.id?
    yaml_name="\$(grep ^job_name ${yaml} | awk '{print \$2}' |  sed 's/\"//g')"

    cp "\$yaml_name".pdb "${meta.id}"_rosettafold_all_atom.pdb

    mamba run --name RFAA extract_metrics.py --name ${meta.id} \\
        --structs "${meta.id}_rosettafold_all_atom.pdb" \\
        --a3ms "\$yaml_name"/*/t000_.msa0.a3m \\
        --pts "\$yaml_name"_aux.pt

    mv "${meta.id}_msa.tsv" "${meta.id}_rosettafold_all_atom_msa.tsv"

    mkdir -p raw
    if [[ -d "\$yaml_name" ]]; then
        mv "\$yaml_name" raw/
    fi
    if [[ -f "\${yaml_name}_aux.pt" ]]; then
        mv "\${yaml_name}_aux.pt" raw/
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_rosettafold_all_atom.pdb"
    touch "${meta.id}.pdb"
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_rosettafold_all_atom_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    mkdir -p raw
    touch raw/${meta.id}_aux.pt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
