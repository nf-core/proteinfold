#!/usr/bin/env python3

import argparse
import glob
import os
import shutil
import sys
import yaml


def parse_args():
    parser = argparse.ArgumentParser(
        description="Merge MMseqs-derived protein MSA mappings into canonical Boltz YAML"
    )
    parser.add_argument("--original_yaml", required=True, help="Canonical/original Boltz YAML")
    parser.add_argument("--mmseqs_yaml", required=True, help="Boltz YAML produced from MMseqs JSON")
    parser.add_argument("--msa_csv", nargs="*", default=[], help="MSA CSV files referenced by mmseqs_yaml")
    parser.add_argument("--msa_csv_dir", default=None, help="Directory containing MSA CSV files")
    parser.add_argument("--output_yaml", required=True, help="Output merged YAML")
    parser.add_argument("--output_csv_dir", required=True, help="Output directory for merged CSV files")
    return parser.parse_args()


def load_yaml(path):
    with open(path, "r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"Expected top-level mapping in YAML: {path}")
    return data


def normalize_id(entity_id):
    if isinstance(entity_id, list):
        normalized = [str(x).strip() for x in entity_id]
        if len(normalized) == 1:
            # Treat [D] and D as the same entity key
            return normalized[0]
        # Order-insensitive key for multi-copy entity ids
        return ("_multi_", tuple(sorted(normalized)))
    if entity_id is None:
        return None
    return str(entity_id).strip()


def extract_msa_map(mmseqs_yaml):
    msa_map = {}
    for seq_item in mmseqs_yaml.get("sequences", []):
        if not isinstance(seq_item, dict) or "protein" not in seq_item:
            continue
        protein = seq_item["protein"]
        protein_id = protein.get("id")
        msa_name = protein.get("msa")
        if protein_id is None or msa_name is None:
            continue
        protein_key = normalize_id(protein_id)
        if protein_key in msa_map and msa_map[protein_key] != msa_name:
            raise ValueError(f"Conflicting MSA assignments for protein id '{protein_id}'")
        msa_map[protein_key] = msa_name
    return msa_map


def main():
    args = parse_args()

    original = load_yaml(args.original_yaml)
    mmseqs = load_yaml(args.mmseqs_yaml)
    msa_map = extract_msa_map(mmseqs)

    if "sequences" not in original or not isinstance(original["sequences"], list):
        raise ValueError("Original Boltz YAML is missing a valid 'sequences' list")

    csv_paths = list(args.msa_csv)
    if args.msa_csv_dir:
        csv_paths.extend(sorted(glob.glob(os.path.join(args.msa_csv_dir, "*.csv"))))
    csv_by_name = {os.path.basename(path): path for path in csv_paths}

    os.makedirs(args.output_csv_dir, exist_ok=True)

    for msa_name, src in csv_by_name.items():
        dst = os.path.join(args.output_csv_dir, msa_name)
        shutil.copy2(src, dst)

    missing_ids = []
    for seq_item in original["sequences"]:
        if not isinstance(seq_item, dict) or "protein" not in seq_item:
            continue
        protein = seq_item["protein"]
        protein_id = protein.get("id")
        if protein_id is None:
            raise ValueError("Protein entry in original Boltz YAML missing 'id'")
        protein_key = normalize_id(protein_id)
        if protein_key not in msa_map:
            missing_ids.append(protein_id)
            continue

        msa_name = msa_map[protein_key]
        if msa_name not in csv_by_name:
            raise ValueError(
                f"MSA file '{msa_name}' referenced for protein '{protein_id}' was not provided"
            )
        protein["msa"] = msa_name

    if missing_ids:
        raise ValueError(
            f"No MSA mapping found for protein id(s): {missing_ids}. "
            "Check id normalization between original and mmseqs YAML."
        )

    with open(args.output_yaml, "w", encoding="utf-8") as out_handle:
        yaml.safe_dump(original, out_handle, sort_keys=False)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
