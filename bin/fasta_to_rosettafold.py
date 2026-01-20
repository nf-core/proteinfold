#!/usr/bin/env python3
import os
import re
import sys
from pathlib import Path


def read_fasta(path, sample_id):
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
                header = line[1:].strip() or f"{sample_id}_chain_{len(entries) + 1}"
                seq_lines = []
            else:
                seq_lines.append(line.replace(" ", "").upper())
    if header is not None:
        entries.append((header, "".join(seq_lines).upper()))
    return entries


def infer_type(header, sequence):
    type_aliases = {
        "protein": "P",
        "prot": "P",
        "aa": "P",
        "pep": "P",
        "peptide": "P",
        "p": "P",
        "rna": "R",
        "r": "R",
        "d": "D",
        "double": "D",
        "ds": "D",
        "dsdna": "D",
        "double_dna": "D",
        "s": "S",
        "single": "S",
        "ss": "S",
        "ssdna": "S",
        "single_dna": "S",
        "single-strand": "S",
        "singlestrand": "S",
    }
    header_lower = header.lower()
    match = re.search(
        r"(?:^|\s)(?:type|entity|molecule|mol)\s*[:=]\s*([A-Za-z0-9_-]+)",
        header_lower,
    )
    if match:
        candidate = match.group(1).lower()
        if candidate in type_aliases:
            return type_aliases[candidate]
    for alias, code in type_aliases.items():
        if alias in {"p", "r", "d", "s"}:
            continue
        if re.search(r"\b" + re.escape(alias) + r"\b", header_lower):
            return code

    seq_set = set(sequence)
    if not sequence:
        return None
    if seq_set <= set("ACUGN"):
        return "R"
    # Default DNA to double-stranded unless explicitly marked single-strand.
    if seq_set <= set("ACTGN"):
        return "D"
    protein_letters = set("ACDEFGHIKLMNPQRSTVWYBXZOU")
    if seq_set <= protein_letters and not (seq_set <= set("ACUGTN")):
        return "P"
    return "P"


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("Usage: fasta_to_rosettafold.py <sample_id> <fasta_path>\n")
        return 1

    sample_id, fasta_path = sys.argv[1], sys.argv[2]
    allowed_ext = (".fa", ".fasta", ".fas", ".faa", ".fna")
    if not fasta_path.lower().endswith(allowed_ext):
        sys.stderr.write(
            f"[ROSETTAFOLD2NA_FASTA] Input file '{fasta_path}' must be a FASTA file.\n"
        )
        return 1

    if not os.path.exists(fasta_path):
        sys.stderr.write(
            f"[ROSETTAFOLD2NA_FASTA] Input FASTA '{fasta_path}' does not exist.\n"
        )
        return 1

    entries = read_fasta(fasta_path, sample_id)
    if not entries:
        sys.stderr.write(
            f"[ROSETTAFOLD2NA_FASTA] No sequences found in '{fasta_path}'.\n"
        )
        return 1

    output_dir = Path("rf2na_input")
    output_dir.mkdir(parents=True, exist_ok=True)

    chain_records = []
    observed_files = set()
    for idx, (header, sequence) in enumerate(entries, start=1):
        chain_type = infer_type(header, sequence)
        if chain_type is None:
            sys.stderr.write(
                f"[ROSETTAFOLD2NA_FASTA] Unable to determine entity type for entry '{header}'. "
                "Please include a token such as 'type=protein', 'type=double_dna', or 'type=single_dna'.\n"
            )
            return 1
        if chain_type not in {"P", "R", "D", "S"}:
            sys.stderr.write(
                f"[ROSETTAFOLD2NA_FASTA] Unable to determine entity type for entry '{header}'. "
                "Allowed types: protein (P), rna (R), double_dna (D), single_dna (S).\n"
            )
            return 1
        safe_name = re.sub(r"[^A-Za-z0-9_.-]+", "_", header) or f"chain_{idx}"
        filename = f"chain_{idx:03d}_{safe_name[:40]}.fa"
        if filename in observed_files:
            filename = f"chain_{idx:03d}_{idx}.fa"
        observed_files.add(filename)
        with open(output_dir / filename, "w") as fh:
            fh.write(f">{header}\n")
            for start in range(0, len(sequence), 80):
                fh.write(sequence[start : start + 80] + "\n")
        chain_records.append((chain_type, filename, header))

    with open(output_dir / "chain_map.tsv", "w") as mapping:
        mapping.write("type\tfilename\theader\n")
        for chain_type, filename, header in chain_records:
            mapping.write(f"{chain_type}\t{filename}\t{header}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
