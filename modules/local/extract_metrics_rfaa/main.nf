/*
 * Extract metrics from RoseTTAFold All-Atom outputs
 */
process EXTRACT_METRICS_RFAA {
    tag "$meta.id"
    label 'process_single'

    container "nf-core/proteinfold_rosettafold_all_atom:2.0.0"

    input:
    tuple val(meta), path(raw)

    output:
    tuple val(meta), path("${meta.id}_plddt.tsv"), emit: multiqc
    tuple val(meta), path("${meta.id}_rosettafold_all_atom_msa.tsv"), optional: true, emit: msa
    tuple val(meta), path("${meta.id}_*_pae.tsv"), optional: true, emit: paes
    tuple val(meta), path("${meta.id}_0_pae.tsv"), optional: true, emit: pae
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mapfile -t rfaa_structs < <(find -L . -name "${meta.id}_rosettafold_all_atom.pdb" | sort)
    mapfile -t rfaa_a3ms < <(find -L . -path "*/t000_.msa0.a3m" | sort)
    mapfile -t rfaa_pts < <(find -L . -name "*_aux.pt" | sort)

    if [[ "${'$'}{#rfaa_structs[@]}" -eq 0 ]]; then
        echo "Could not find RoseTTAFold All-Atom structure for ${meta.id}" >&2
        exit 1
    fi

    cmd=(mamba run --name RFAA extract_metrics.py --name ${meta.id} --structs "${'$'}{rfaa_structs[@]}")
    if [[ "${'$'}{#rfaa_a3ms[@]}" -gt 0 ]]; then
        cmd+=(--a3ms "${'$'}{rfaa_a3ms[@]}")
    fi
    if [[ "${'$'}{#rfaa_pts[@]}" -gt 0 ]]; then
        cmd+=(--pts "${'$'}{rfaa_pts[@]}")
    fi
    "${'$'}{cmd[@]}"

    if [[ -f "${meta.id}_msa.tsv" ]]; then
        mv "${meta.id}_msa.tsv" "${meta.id}_rosettafold_all_atom_msa.tsv"
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_rosettafold_all_atom_msa.tsv"
    touch "${meta.id}_0_pae.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>/dev/null | sed 's/Python //g' || echo "unknown")
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
