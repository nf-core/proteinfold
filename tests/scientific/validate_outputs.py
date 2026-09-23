#!/usr/bin/env python3
"""Validate ProteinFold scientific-test structures and confidence metrics."""

import argparse
import csv
import math
import tempfile
import urllib.request
import warnings
from pathlib import Path

from Bio.PDB import MMCIFParser, PDBParser
from Bio.PDB.PDBExceptions import PDBConstructionWarning

warnings.filterwarnings("ignore", category=PDBConstructionWarning, message=".*Ignoring unrecognized record.*")
warnings.filterwarnings("error", category=PDBConstructionWarning, message=".*discontinuous.*")
warnings.filterwarnings("error", category=PDBConstructionWarning, message=".*duplicate.*")
warnings.filterwarnings("error", category=PDBConstructionWarning, message=".*could not assign element.*")


def input_ids(samplesheet: str) -> list[str]:
    if samplesheet.startswith(("http://", "https://")):
        with urllib.request.urlopen(samplesheet) as response:  # noqa: S310 - fixed test data URL
            lines = response.read().decode().splitlines()
    else:
        lines = Path(samplesheet).read_text().splitlines()
    ids = [row[0].strip() for row in list(csv.reader(lines))[1:] if row and row[0].strip()]
    if not ids:
        raise AssertionError(f"Samplesheet is empty: {samplesheet}")
    return ids


def parser_canary() -> None:
    malformed = "TITLE malformed\nEND\n"
    valid = (
        "ATOM      1  N   ALA A   1       0.000   0.000   0.000  1.00  0.00           N\n"
        "ATOM      2  CA  ALA A   1       1.458   0.000   0.000  1.00  0.00           C\n"
        "ATOM      3  C   ALA A   1       2.009   1.390   0.000  1.00  0.00           C\n"
        "END\n"
    )
    invalid = (
        "ATOM      1  N   ALA A   1       0.000   0.000   0.000  1.00  0.00           N\n"
        "ATOM      2  CA  ALA A   1       1.458   2.3X1   0.000  1.00  0.00           C\n"
        "END\n"
    )
    with tempfile.TemporaryDirectory(prefix="proteinfold-validator-") as tmpdir:
        paths = {}
        for name, content in {"malformed": malformed, "valid": valid, "invalid": invalid}.items():
            path = Path(tmpdir, f"{name}.pdb")
            path.write_text(content)
            paths[name] = path

        parser = PDBParser(QUIET=True)
        malformed_structure = parser.get_structure("malformed", paths["malformed"])
        assert not list(malformed_structure.get_residues()), "Parser accepted a structure without residues"
        assert list(parser.get_structure("valid", paths["valid"]).get_residues()), "Parser rejected valid PDB"
        try:
            parser.get_structure("invalid", paths["invalid"])
        except Exception:
            pass
        else:
            raise AssertionError("Parser accepted malformed coordinates")


def validate_structure(path: Path) -> int:
    if path.suffix == ".pdb":
        parser = PDBParser(QUIET=False)
    elif path.suffix in {".cif", ".mmcif"}:
        parser = MMCIFParser(QUIET=False)
    else:
        raise AssertionError(f"Unsupported structure format: {path}")
    residues = list(parser.get_structure("prediction", path).get_residues())
    assert residues, f"Structure has no residues: {path}"
    return len(residues)


def validate_plddt(path: Path) -> tuple[int, int, float]:
    rows = [line.split("\t") for line in path.read_text().splitlines()]
    assert len(rows) > 1, f"pLDDT file has no data rows: {path}"
    assert rows[0][0] == "Positions", f"Unexpected pLDDT header in {path}: {rows[0][0]}"
    values = []
    for row in rows[1:]:
        assert len(row) == len(rows[0]), f"Inconsistent pLDDT column count in {path}"
        values.extend(float(value) for value in row[1:])
    assert values, f"pLDDT file contains no scores: {path}"
    assert all(math.isfinite(value) and 0 <= value <= 100 for value in values), (
        f"pLDDT values outside 0-100 or non-finite: {path}"
    )
    mean_plddt = sum(values) / len(values)
    assert mean_plddt >= 5.0, f"Suspiciously low mean pLDDT: {path}"
    return len(rows) - 1, len(values), mean_plddt


def validate_pae(path: Path) -> tuple[int, int]:
    rows = [line.split("\t") for line in path.read_text().splitlines() if line]
    assert rows, f"Empty PAE matrix: {path}"
    assert all(len(row) == len(rows) for row in rows), f"PAE matrix is not square: {path}"
    values = [float(value) for row in rows for value in row]
    assert all(math.isfinite(value) and 0 <= value <= 31.75 for value in values), (
        f"PAE values outside 0-31.75 or non-finite: {path}"
    )
    return len(rows), len(rows[0])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--extension", required=True, choices=[".pdb", ".cif", ".mmcif"])
    parser.add_argument("--outdir", required=True, type=Path)
    parser.add_argument("--samplesheet", required=True)
    args = parser.parse_args()

    parser_canary()
    ids = input_ids(args.samplesheet)
    mode_dir = args.outdir / args.mode
    assert mode_dir.is_dir(), f"{args.display_name} output directory does not exist: {mode_dir}"

    structure_dirs = [path for path in mode_dir.rglob("top_ranked_structures") if path.is_dir()]
    assert structure_dirs, f"No top_ranked_structures directory below {mode_dir}"
    structures = sorted(path for directory in structure_dirs for path in directory.glob(f"*{args.extension}"))
    assert structures, f"{args.display_name} produced no {args.extension} structures"
    for identifier in ids:
        assert any(identifier in path.name for path in structures), (
            f"No {args.display_name} structure for input {identifier}; found {[path.name for path in structures]}"
        )
    for structure in structures:
        residue_count = validate_structure(structure)
        print(f"Validated structure: {structure.name} ({residue_count} residues)")

    plddt_files = sorted(mode_dir.rglob("*plddt.tsv"))
    assert plddt_files, f"{args.display_name} produced no pLDDT metrics"
    for identifier in ids:
        assert any(identifier in path.name for path in plddt_files), (
            f"No {args.display_name} pLDDT metrics for input {identifier}"
        )
    for path in plddt_files:
        position_count, score_count, mean_plddt = validate_plddt(path)
        print(
            f"Validated pLDDT: {path.name} "
            f"({position_count} positions, {score_count} scores, mean={mean_plddt:.1f})"
        )

    pae_files = sorted(path for path in mode_dir.rglob("*.tsv") if path.parent.name == "paes")
    for path in pae_files:
        row_count, column_count = validate_pae(path)
        print(f"Validated PAE: {path.name} ({row_count}x{column_count} matrix)")

    print(
        f"Validated {args.display_name}: {len(ids)} inputs, {len(structures)} structures, "
        f"{len(plddt_files)} pLDDT files, {len(pae_files)} PAE matrices"
    )


if __name__ == "__main__":
    main()
