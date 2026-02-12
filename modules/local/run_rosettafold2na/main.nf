/*
 * Run RF2NA (RoseTTAFold 2 for Nucleic Acids)
 */
process RUN_ROSETTAFOLD2NA {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_rosettafold2na:2.0.0"

    input:
    tuple val(meta), path(rf2na_input)
    path ('bfd/*')
    path ('UniRef30_2020_06/*')
    path ('pdb100_2021Mar03/*')
    path ('RNA/*')
    path ('network/weights/*')

    output:
    path ("raw/**")                                            , emit: raw
    tuple val(meta), path("${meta.id}_rosettafold2na.pdb")     , emit: top_ranked_pdb
    tuple val(meta), path("raw/*.pdb")                         , emit: pdb
    tuple val(meta), path("${meta.id}_plddt.tsv")              , emit: multiqc
    tuple val(meta), path("${meta.id}_rosettafold2na_msa.tsv") , emit: msa
    tuple val(meta), path("${meta.id}_0_pae.tsv")              , emit: pae
    path "versions.yml"                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_RF2NA module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    def VERSION = 'v0.2' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    # Otherwise will through error when running .command.{sh,run} for debugging
    if [ ! -e "\$PWD/run_RF2NA.sh" ]; then
        ln -s /app/RoseTTAFold2NA/run_RF2NA.sh ./
        mkdir ./input_prep
        ln -s /app/RoseTTAFold2NA/input_prep/* ./input_prep
        ln -s /app/RoseTTAFold2NA/network/* ./network
    fi

    rf2na_input_dir="\${rf2na_input:-rf2na_input}"

    chain_map="\${rf2na_input_dir}/chain_map.tsv"
    if [ ! -s "\$chain_map" ]; then
        echo "[ROSETTAFOLD2NA] Missing chain_map.tsv produced by ROSETTAFOLD2NA_FASTA." >&2
        exit 1
    fi

    chain_args=()
    while IFS=\$'\\t' read -r chain_type chain_file _; do
        [ -z "\$chain_type" ] && continue
        case "\${chain_type}" in
            P|R|D|S) ;;
            *) echo "[ROSETTAFOLD2NA] Unsupported chain type '\${chain_type}'. Allowed types: P, R, D, S." >&2; exit 1 ;;
        esac
        chain_args+=( "\${chain_type}:\${rf2na_input_dir}/\${chain_file}" )
    done < <(tail -n +2 "\$chain_map")

    if [ "\${#chain_args[@]}" -eq 0 ]; then
        echo "[ROSETTAFOLD2NA] No valid chain specifications found in chain_map.tsv." >&2
        exit 1
    fi

    ./run_RF2NA.sh ${meta.id}_rf2na_output "\${chain_args[@]}"

    ## Create raw directory for intermediate files
    mkdir -p raw

    ## Copy top ranked model to root and raw
    cp ${meta.id}_rf2na_output/models/model_00.pdb ./${meta.id}_rosettafold2na.pdb
    cp ${meta.id}_rf2na_output/models/*.pdb raw/ # TODO check other raw files

    # Extract PAE matrix from NPZ and save as TSV for reporting
    /conda/envs/RF2NA/bin/python3 - <<'PY' "${meta.id}_rf2na_output/models/model_00.npz" "${meta.id}_0_pae.tsv"
import numpy as np, sys
npz, out = sys.argv[1], sys.argv[2]
d = np.load(npz)
np.savetxt(out, d["pae"], fmt="%.3f", delimiter="\t")
PY

    A3M_ARGS="${'$'}(find "${meta.id}_rf2na_output" -maxdepth 1 -name "*.a3m" -print | sed 's/^/ --a3ms /' | tr -d '\n')"
    extract_metrics.py --name ${meta.id} \
        --structs "${meta.id}_rf2na_output/models/model_00.pdb" ${'$'}A3M_ARGS


    mv "${meta.id}_msa.tsv" "${meta.id}_rosettafold2na_msa.tsv"

    ## Move rf2na output directory to raw for save_intermediates
    mv ${meta.id}_rf2na_output/* raw/

    printf '"%s":\n  python: %s\n' \
        "${task.process}" \
        "\$(/conda/envs/RF2NA/bin/python3 --version | sed 's/Python //g')" > versions.yml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rosettafold2na: $VERSION
    END_VERSIONS
    """

    stub:
    def VERSION = 'v0.2' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    mkdir -p raw
    touch "${meta.id}_rosettafold2na.pdb"
    touch raw/model_00.pdb
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_rosettafold2na_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rosettafold2na: $VERSION
    END_VERSIONS
    """
}
