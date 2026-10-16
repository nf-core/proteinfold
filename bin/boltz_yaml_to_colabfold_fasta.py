#!/usr/bin/env python3

import argparse
import sys
import yaml


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert Boltz YAML to a ColabFold/MMseqs-compatible query FASTA"
    )
    parser.add_argument("yaml_in", help="Input Boltz YAML file")
    parser.add_argument("--id", required=True, help="Output FASTA header id")
    parser.add_argument("--output", required=True, help="Output FASTA path")
    return parser.parse_args()


def entity_to_query_token(seq_item):
    if not isinstance(seq_item, dict) or len(seq_item) != 1:
        raise ValueError("Each entry in 'sequences' must be a single-key mapping")

    seq_type, details = next(iter(seq_item.items()))
    if not isinstance(details, dict):
        raise ValueError(f"Invalid '{seq_type}' entry format")

    id_field = details.get("id")
    copies = 1
    if isinstance(id_field, list):
        copies = len(id_field)
    elif isinstance(id_field, str):
        # Fallback parser may leave list-like ids as strings (e.g. "[A, B]")
        stripped = id_field.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            entries = [x.strip() for x in stripped[1:-1].split(",") if x.strip()]
            copies = max(1, len(entries))

    if seq_type == "protein":
        seq = details.get("sequence")
        if not seq:
            raise ValueError("Protein entry missing 'sequence'")
        return [seq] * copies

    if seq_type == "rna":
        seq = details.get("sequence")
        if not seq:
            raise ValueError("RNA entry missing 'sequence'")
        return [f"rna|{seq}"] * copies

    if seq_type == "dna":
        seq = details.get("sequence")
        if not seq:
            raise ValueError("DNA entry missing 'sequence'")
        return [f"dna|{seq}"] * copies

    if seq_type == "ligand":
        smiles = details.get("smiles")
        ccd = details.get("ccd")
        if smiles:
            return [f"smiles|{smiles}"] * copies
        if ccd:
            return [f"ccd|{ccd}"] * copies
        raise ValueError("Ligand entry missing 'smiles' or 'ccd'")

    raise ValueError(f"Unsupported sequence type '{seq_type}'")


def main():
    args = parse_args()

    with open(args.yaml_in, "r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)

    sequences = data.get("sequences") if isinstance(data, dict) else None
    if not isinstance(sequences, list) or len(sequences) == 0:
        raise ValueError("Input Boltz YAML must contain a non-empty 'sequences' list")

    tokens = []
    for item in sequences:
        tokens.extend(entity_to_query_token(item))
    query = ":".join(tokens)

    with open(args.output, "w", encoding="utf-8") as out:
        out.write(f">{args.id}\n{query}\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
