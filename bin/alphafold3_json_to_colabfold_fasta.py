#!/usr/bin/env python3
"""Extract protein queries from an AlphaFold3 input JSON for MMseqs/ColabFold."""

import argparse
import json
from pathlib import Path


def _single_job(document):
    if isinstance(document, list):
        if len(document) != 1:
            raise ValueError(
                "ColabFold2 requires one AlphaFold3 job per samplesheet row; "
                f"the JSON contains {len(document)} jobs"
            )
        document = document[0]
    if not isinstance(document, dict):
        raise ValueError("AlphaFold3 JSON must be an object or a one-element list")
    return document


def protein_queries(document):
    queries = []
    for entity in document.get("sequences", []):
        if not isinstance(entity, dict) or "protein" not in entity:
            continue
        protein = entity["protein"]
        sequence = protein.get("sequence") if isinstance(protein, dict) else None
        if not sequence:
            raise ValueError("AlphaFold3 protein entity is missing its sequence")
        entity_ids = protein.get("id")
        copies = len(entity_ids) if isinstance(entity_ids, list) else 1
        queries.extend([sequence] * max(1, copies))
    if not queries:
        raise ValueError(
            "Offline ColabFold2 MSA generation needs at least one protein entity; "
            "use --use_msa_server for an RNA/ligand-only AlphaFold3 JSON"
        )
    return queries


def main():
    parser = argparse.ArgumentParser(
        description="Convert the protein entities in AlphaFold3 JSON to a ColabFold query FASTA"
    )
    parser.add_argument("json_in")
    parser.add_argument("--id", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    with open(args.json_in, encoding="utf-8") as handle:
        document = _single_job(json.load(handle))
    sequence = ":".join(protein_queries(document))
    Path(args.output).write_text(f">{args.id}\n{sequence}\n", encoding="utf-8")


if __name__ == "__main__":
    main()
