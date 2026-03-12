#!/usr/bin/env python3
"""
Convert FASTA files to Protenix JSON input format.

Protenix expects a JSON array where each element has:
  - "name": job name
  - "sequences": list of chain definitions
  - "covalent_bonds": []

Usage:
    fasta_to_protenix_json.py <FASTA> <ID> -o <OUTPUT_DIR>
"""

import argparse
import json
import os
import re
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


def fasta_to_protenix_json(fasta_file, sample_id):
    """Convert a FASTA file to Protenix JSON format."""
    entries = parse_fasta(fasta_file)

    if not entries:
        print(f"Error: No sequences found in {fasta_file}", file=sys.stderr)
        sys.exit(1)

    sequences = []
    for header, sequence in entries:
        entity_type = infer_entity_type(header, sequence)

        if entity_type == "protein":
            sequences.append({
                "proteinChain": {
                    "sequence": sequence,
                    "count": 1
                }
            })
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
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    json_data = fasta_to_protenix_json(args.FASTA, args.ID)
    output_path = os.path.join(args.output_dir, f"{args.ID}.json")

    with open(output_path, "w") as f:
        json.dump(json_data, f, indent=2)

    print(f"Generated: {output_path}")


if __name__ == "__main__":
    main()
