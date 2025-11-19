/*
 * Run RF2NA (RoseTTAFold 2 for Nucleic Acids)
 */
process RUN_ROSETTAFOLD2NA {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_rosettafold2na:2.0.0"

    input:
    tuple val(meta), path(protein_fasta), path(interaction_fasta)
    path ('bfd/*')
    path ('UniRef30_2020_06/*')
    path ('pdb100_2021Mar03/*')
    path ('RNA/*')
    path ('network/weights/*')

    output:
    tuple val(meta), path("${meta.id}_rf2na.pdb"), emit: pdb
    tuple val(meta), path("${meta.id}_plddt_mqc.tsv"), emit: multiqc
    tuple val(meta), path("${meta.id}_rosettafold2na_msa.tsv"), emit: msa
    tuple val(meta), path("${meta.id}_0_pae.tsv"), emit: pae
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_RF2NA module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    def args = task.ext.args ?: ''
    def VERSION = 'dev' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    # Otherwise will through error when running .command.{sh,run} for debugging
    if [ ! -e "\$PWD/run_RF2NA.sh" ]; then
        ln -s /app/RoseTTAFold2NA/run_RF2NA.sh ./
        mkdir ./input_prep
        ln -s /app/RoseTTAFold2NA/input_prep/* ./input_prep
        ln -s /app/RoseTTAFold2NA/network/* ./network
    fi

    ./run_RF2NA.sh ${meta.id}_rf2na_output $protein_fasta ${meta.interaction_type}:${interaction_fasta}

    cp ${meta.id}_rf2na_output/models/model_00.pdb ./${meta.id}_rf2na.pdb

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

    mv "${meta.id}_plddt.tsv" "${meta.id}_plddt_mqc.tsv"
    if [ -f "${meta.id}_msa.tsv" ]; then
        mv "${meta.id}_msa.tsv" "${meta.id}_rosettafold2na_msa.tsv"
    fi

    printf '"%s":\n  python: %s\n' \
        "${task.process}" \
        "\$(/conda/envs/RF2NA/bin/python3 --version | sed 's/Python //g')" > versions.yml
    """

    stub:
    """
    touch "${meta.id}_rf2na.pdb"
    touch "${meta.id}_plddt_mqc.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_rosettafold2na_msa.tsv"

    printf '"%s":\n  python: %s\n' \
        "${task.process}" \
        "\$(/conda/envs/RF2NA/bin/python3 --version | sed 's/Python //g')" > versions.yml
    """
}
