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
    tuple val(meta), path ("raw/**")                                    , emit: raw
    tuple val(meta), path ("${meta.id}_rosettafold_all_atom.pdb")       , emit: pdb
    path "versions.yml"                                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

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

    mkdir -p raw
    cp "${meta.id}"_rosettafold_all_atom.pdb raw/
    if [[ -d "\$yaml_name" ]]; then
        mv "\$yaml_name" raw/
    fi
    if [[ -f "\${yaml_name}_aux.pt" ]]; then
        mv "\${yaml_name}_aux.pt" raw/
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
        rosettafold-all-atom: \$(cd /app/RoseTTAFold-All-Atom && git rev-parse HEAD 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_rosettafold_all_atom.pdb"
    touch "${meta.id}.pdb"
    mkdir -p raw
    touch raw/${meta.id}_aux.pt
    touch raw/${meta.id}_rosettafold_all_atom.pdb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        rosettafold-all-atom: \$(cd /app/RoseTTAFold-All-Atom && git rev-parse HEAD 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
