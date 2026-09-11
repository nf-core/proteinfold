#!/usr/bin/env python3
from __future__ import annotations

import argparse
import string
import sys
from collections.abc import Sequence

ENTITY_TYPES = ("protein", "ccd", "smiles", "dna", "rna")
_NUCLEIC, _DNA, _RNA = set("ACGTUN"), set("ACGTN"), set("ACGUN")
_PROTEIN = set("ACDEFGHIKLMNPQRSTVWYBXZJUO")


class EntityTypeError(ValueError):
    pass


def infer_entity_type(header: str, sequence: str) -> str:
    fields = header.split("|")
    explicit = fields[1].strip().lower() if len(fields) > 1 else None
    seq = "".join(sequence.split()).upper()
    if not seq:
        raise EntityTypeError(f"empty sequence for header {header!r}")
    letters = set(seq)
    if explicit:
        if explicit not in ENTITY_TYPES:
            explicit = None
        else:
            valid = {
                "protein": letters <= _PROTEIN,
                "dna": letters <= _DNA,
                "rna": letters <= _RNA,
                "ccd": True,
                "smiles": True,
            }[explicit]
            if not valid:
                raise EntityTypeError(f"sequence for explicit {explicit} entity contains invalid characters")
            return explicit
    if letters <= _RNA and "U" in letters:
        return "rna"
    if letters <= _DNA and "T" in letters:
        return "dna"
    if letters <= _NUCLEIC:
        raise EntityTypeError(f"ambiguous unannotated sequence in header {header!r}; use an explicit |dna or |rna annotation")
    if letters <= _PROTEIN:
        return "protein"
    raise EntityTypeError(f"unrecognised or malformed sequence in header {header!r}")


def parse_args(args: Sequence[str] | None = None) -> argparse.Namespace:
    """
    Parse command line arguments for the script.

    Required arguments:
        FASTA: Input fasta file path
        ID: Identifier for the output file
    Optional arguments:
        --yaml_out: output path for Boltz YAML
    """
    Description = "Convert fasta files to Boltz format."
    Epilog = "Example usage: python fasta_to_boltz.py <FASTA> <ID> [--yaml_out output.yaml]"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)

    parser.add_argument(
        "FASTA",
        help="Input fasta file."
    )
    parser.add_argument(
        "ID",
        help="ID for output file name."
    )
    parser.add_argument(
        "--yaml_out",
        default=None,
        help="Optional output path for Boltz YAML."
    )

    return parser.parse_args(args)



def write_boltz_yaml(sample_id, entities, yaml_out):
    output_yaml = yaml_out or f"{sample_id}.yaml"
    with open(output_yaml, "w", encoding="utf-8") as out:
        out.write("version: 1\n")
        out.write("sequences:\n")
        for entry in entities:
            entity_type = entry["entity_type"]
            entity_ids = entry["id"]
            if len(entity_ids) == 1:
                entity_id = entity_ids[0]
            else:
                entity_id = "[" + ", ".join(entity_ids) + "]"
            sequence = entry["sequence"]
            if entity_type == "protein":
                out.write(f"  - protein:\n      id: {entity_id}\n      sequence: {sequence}\n")
            elif entity_type == "rna":
                out.write(f"  - rna:\n      id: {entity_id}\n      sequence: {sequence}\n")
            elif entity_type == "dna":
                out.write(f"  - dna:\n      id: {entity_id}\n      sequence: {sequence}\n")
            elif entity_type == "smiles":
                out.write(f"  - ligand:\n      id: {entity_id}\n      smiles: {sequence}\n")
            elif entity_type == "ccd":
                out.write(f"  - ligand:\n      id: {entity_id}\n      ccd: {sequence}\n")
            else:
                raise ValueError(f"Unsupported entity type '{entity_type}' for sequence id '{entity_id}'")


def fasta_to_boltz(fasta_file, sample_id, yaml_out=None):
    """
    Convert a FASTA file to Boltz format.

    Args:
        fasta_file (str): Path to the input FASTA file
        sample_id (str): Sample identifier for the output file
    """
    all_combinations = list(string.ascii_uppercase) + list(string.ascii_lowercase) + [str(x) for x in range(0, 10)]

    counter = 0

    with open(fasta_file, "r") as f:
        lines = f.readlines()

    seq_lines = []
    header = None
    entities = []
    entity_lookup = {}

    def add_entity(current_header, current_seq_lines):
        nonlocal counter
        sequence = "".join(current_seq_lines)
        entity_type = infer_entity_type(current_header, sequence)
        entity_id = all_combinations[counter]
        counter += 1

        key = (entity_type, sequence)
        if key in entity_lookup:
            entity_lookup[key]["id"].append(entity_id)
            return

        entry = {
            "id": [entity_id],
            "entity_type": entity_type,
            "sequence": sequence
        }
        entities.append(entry)
        entity_lookup[key] = entry

    for line in lines:
        line = line.strip()
        if line.startswith(">"):
            # Write previous entry if exists
            if header is not None:
                add_entity(header, seq_lines)
            header = line
            seq_lines = []
        else:
            seq_lines.append(line)

    # Write last entry
    if header is not None:
        add_entity(header, seq_lines)

    if len(entities) > 0:
        write_boltz_yaml(sample_id, entities, yaml_out)


def main(args=None):
    """
    Main function to process FASTA files and create Boltz formatted FASTA files.
    """
    args = parse_args(args)
    fasta_to_boltz(args.FASTA, args.ID, args.yaml_out)


if __name__ == "__main__":
    sys.exit(main())
