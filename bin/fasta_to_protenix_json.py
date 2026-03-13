#!/usr/bin/env python3
"""
Convert FASTA files to Protenix JSON input format.

Protenix expects a JSON array where each element has:
  - "name": job name
  - "sequences": list of chain definitions
  - "covalent_bonds": []

Optionally includes pre-computed MSA paths (pairedMsaPath, unpairedMsaPath)
for each protein chain when --msa CSV files are provided from SPLIT_MSA.

Usage:
    fasta_to_protenix_json.py <FASTA> <ID> -o <OUTPUT_DIR> [--msa file1.csv file2.csv]
"""

import argparse
import csv
import json
import os
import sys


def infer_entity_type(header, sequence):
    """Infer entity type from FASTA header and sequence content."""
    header_lower = header.lower()
    if "dna" in header_lower:
        return "dna"
    if "rna" in header_lower:
        return "rna"
    if "ligand" in header_lower or "smiles" in header_lower:
        return "ligand"

    seq = sequence.strip().upper()
    seq_set = set(seq)
    if seq_set <= set("ACUGN") and len(seq) > 1:
        return "rna"
    if seq_set <= set("ACTGN") and len(seq) > 1:
        return "dna"

    return "protein"


def parse_fasta(fasta_file):
    """Parse a FASTA file into list of (header, sequence) tuples."""
    entries = []
    header = None
    seq_lines = []

    with open(fasta_file, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                if header is not None:
                    entries.append((header, "".join(seq_lines)))
                header = line[1:]
                seq_lines = []
            elif line:
                seq_lines.append(line)

    if header is not None:
        entries.append((header, "".join(seq_lines)))

    return entries


def csv_to_a3m(csv_file, output_dir, chain_idx):
    """Convert MSA CSV (from SPLIT_MSA/msa_manager.py) to paired/unpaired A3M files."""
    paired = []
    unpaired = []

    with open(csv_file, "r") as f:
        reader = csv.reader(f)
        next(reader)  # skip header row (key,sequence)
        for row in reader:
            key = int(row[0])
            seq = row[1]
            if key == -1:
                unpaired.append(seq)
            else:
                paired.append(seq)

    chain_dir = os.path.join(output_dir, str(chain_idx))
    os.makedirs(chain_dir, exist_ok=True)

    pairing_path = os.path.join(chain_dir, "pairing.a3m")
    non_pairing_path = os.path.join(chain_dir, "non_pairing.a3m")

    with open(pairing_path, "w") as f:
        for i, seq in enumerate(paired):
            f.write(f">paired_{i}\n{seq}\n")

    with open(non_pairing_path, "w") as f:
        for i, seq in enumerate(unpaired):
            f.write(f">unpaired_{i}\n{seq}\n")

    return pairing_path, non_pairing_path


def fasta_to_protenix_json(fasta_file, sample_id, msa_files=None, output_dir="."):
    """Convert a FASTA file to Protenix JSON format with optional MSA."""
    entries = parse_fasta(fasta_file)

    if not entries:
        print(f"Error: No sequences found in {fasta_file}", file=sys.stderr)
        sys.exit(1)

    msa_output_dir = os.path.join(output_dir, "msa_protenix")
    os.makedirs(msa_output_dir, exist_ok=True)

    sequences = []
    protein_idx = 0
    unique_proteins = {}
    msa_counter = 0

    for header, sequence in entries:
        entity_type = infer_entity_type(header, sequence)

        if entity_type == "protein":
            chain_def = {
                "proteinChain": {
                    "sequence": sequence,
                    "count": 1
                }
            }
            if msa_files:
                if sequence not in unique_proteins:
                    unique_proteins[sequence] = msa_counter
                    msa_counter += 1
                this_msa_idx = unique_proteins[sequence]
                if this_msa_idx < len(msa_files):
                    pairing_path, non_pairing_path = csv_to_a3m(
                        msa_files[this_msa_idx], msa_output_dir, protein_idx
                    )
                    chain_def["proteinChain"]["pairedMsaPath"] = pairing_path
                    chain_def["proteinChain"]["unpairedMsaPath"] = non_pairing_path
            protein_idx += 1
            sequences.append(chain_def)
        elif entity_type == "dna":
            sequences.append({
                "dnaSequence": {
                    "sequence": sequence,
                    "count": 1
                }
            })
        elif entity_type == "rna":
            sequences.append({
                "rnaSequence": {
                    "sequence": sequence,
                    "count": 1
                }
            })
        elif entity_type == "ligand":
            sequences.append({
                "ligand": {
                    "ligand": sequence,
                    "count": 1
                }
            })

    job = {
        "name": sample_id,
        "sequences": sequences,
        "covalent_bonds": []
    }

    return [job]


def main():
    parser = argparse.ArgumentParser(
        description="Convert FASTA to Protenix JSON format"
    )
    parser.add_argument("FASTA", help="Input FASTA file")
    parser.add_argument("ID", help="Sample identifier")
    parser.add_argument(
        "-o", "--output-dir", default=".",
        help="Output directory (default: current dir)"
    )
    parser.add_argument(
        "--msa",
        nargs='*',
        default=[],
        help="MSA CSV files for protein sequences (from SPLIT_MSA)."
    )
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    json_data = fasta_to_protenix_json(
        args.FASTA, args.ID,
        msa_files=args.msa if args.msa else None,
        output_dir=args.output_dir
    )
    output_path = os.path.join(args.output_dir, f"{args.ID}.json")

    with open(output_path, "w") as f:
        json.dump(json_data, f, indent=2)

    print(f"Generated: {output_path}")


if __name__ == "__main__":
    main()

