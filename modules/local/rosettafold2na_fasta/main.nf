process ROSETTAFOLD2NA_FASTA {
    tag   "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("rf2na_input", type: "dir"), emit: prepared_input
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python3 - <<'PY' "${meta.id}" "${fasta}"
import os
import re
import sys
from pathlib import Path

sample_id, fasta_path = sys.argv[1], sys.argv[2]
allowed_ext = (".fa", ".fasta", ".fas", ".faa", ".fna")
if not fasta_path.lower().endswith(allowed_ext):
    sys.stderr.write(f"[ROSETTAFOLD2NA_FASTA] Input file '{fasta_path}' must be a FASTA file.\\n")
    sys.exit(1)

if not os.path.exists(fasta_path):
    sys.stderr.write(f"[ROSETTAFOLD2NA_FASTA] Input FASTA '{fasta_path}' does not exist.\\n")
    sys.exit(1)

def read_fasta(path):
    entries = []
    header = None
    seq_lines = []
    with open(path, "r") as handle:
        for raw in handle:
            line = raw.strip()
            if not line:
                continue
            if line.startswith(">"):
                if header is not None:
                    entries.append((header, "".join(seq_lines).upper()))
                header = line[1:].strip() or f"{sample_id}_chain_{len(entries)+1}"
                seq_lines = []
            else:
                seq_lines.append(line.replace(" ", "").upper())
    if header is not None:
        entries.append((header, "".join(seq_lines).upper()))
    return entries

def infer_type(header, sequence):
    type_aliases = {
        "protein": "P", "prot": "P", "aa": "P", "pep": "P", "peptide": "P", "p": "P",
        "rna": "R", "r": "R",
        "double": "D", "ds": "D", "dsdna": "D", "double_dna": "D",
        "single": "S", "ss": "S", "ssdna": "S", "single_dna": "S", "single-strand": "S", "singlestrand": "S"
    }
    header_lower = header.lower()
    match = re.search(r"(?:type|entity|molecule|mol)[:=]\\s*([A-Za-z0-9_-]+)", header_lower)
    if match:
        candidate = match.group(1).lower()
        if candidate in type_aliases:
            return type_aliases[candidate]
    for alias, code in type_aliases.items():
        if re.search(r"\\b" + re.escape(alias) + r"\\b", header_lower):
            return code

    seq_set = set(sequence)
    if not sequence:
        return None
    if seq_set <= set("ACUGN"):
        return "R"
    # default DNA to double-stranded unless explicitly marked single-strand
    if seq_set <= set("ACTGN"):
        return "D"
    protein_letters = set("ACDEFGHIKLMNPQRSTVWYBXZOU")
    if seq_set <= protein_letters and not (seq_set <= set("ACUGTN")):
        return "P"
    return "P"

entries = read_fasta(fasta_path)
if not entries:
    sys.stderr.write(f"[ROSETTAFOLD2NA_FASTA] No sequences found in '{fasta_path}'.\\n")
    sys.exit(1)

output_dir = Path("rf2na_input")
output_dir.mkdir(parents=True, exist_ok=True)

chain_records = []
observed_files = set()
for idx, (header, sequence) in enumerate(entries, start=1):
    chain_type = infer_type(header, sequence)
    if chain_type is None:
        sys.stderr.write(
            f"[ROSETTAFOLD2NA_FASTA] Unable to determine entity type for entry '{header}'. "
            "Please include a token such as 'type=protein', 'type=double_dna', or 'type=single_dna'.\\n"
        )
        sys.exit(1)
    if chain_type not in {"P", "R", "D", "S"}:
        sys.stderr.write(
            f"[ROSETTAFOLD2NA_FASTA] Unable to determine entity type for entry '{header}'. "
            "Allowed types: protein (P), rna (R), double_dna (D), single_dna (S).\\n"
        )
        sys.exit(1)
    safe_name = re.sub(r"[^A-Za-z0-9_.-]+", "_", header) or f"chain_{idx}"
    filename = f"chain_{idx:03d}_{safe_name[:40]}.fa"
    if filename in observed_files:
        filename = f"chain_{idx:03d}_{idx}.fa"
    observed_files.add(filename)
    with open(output_dir / filename, "w") as fh:
        fh.write(f">{header}\\n")
        for start in range(0, len(sequence), 80):
            fh.write(sequence[start:start+80] + "\\n")
    chain_records.append((chain_type, filename, header))

with open(output_dir / "chain_map.tsv", "w") as mapping:
    mapping.write("type\\tfilename\\theader\\n")
    for chain_type, filename, header in chain_records:
        mapping.write(f"{chain_type}\\t{filename}\\t{header}\\n")
PY

    cat <<'END_VERSIONS' > versions.yml
"${task.process}":
    python: \$(python3 --version | sed 's/Python //g')
END_VERSIONS
    """

    stub:
    """
    mkdir -p rf2na_input
    touch rf2na_input/chain_map.tsv

    cat <<'END_VERSIONS' > versions.yml
"${task.process}":
    python: \$(python3 --version | sed 's/Python //g')
END_VERSIONS
    """
}
