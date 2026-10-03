#!/usr/bin/env python3
"""Validate ProteinFold scientific-test structures and confidence metrics.

ColabFold2-specific behaviour (shared with the upstream per-mode checks):

* ColabFold2 backends publish directly under their public mode token. Most are
  requested by their own name (``--mode opendde`` -> ``opendde``); only
  ``alphafold3`` and ``boltz2`` need the ``colabfold2-`` prefix, because those two
  names already select the standalone AlphaFold3 and Boltz modes. The retired
  ``-af3`` short form no longer resolves.
* ``--structure-only`` relaxes the confidence gates for the ESMFold2
  language-model backends, which ship no confidence head by upstream design
  (NO_CONFIDENCE_HEAD): pLDDT cells are literal ``n/a`` (or all-zero in older
  extractions) and the PAE matrix is all-NaN, so the validator requires those
  exact identity markers in addition to file shape and squareness.
* Interface metrics (``*_iptm.tsv``, ``*_chainwise_iptm.tsv``, ``*_ipsae.tsv``,
  ``*_chainwise_ipsae.tsv``) are validated wherever they carry content and
  tolerated as empty placeholders, which is what monomer and structure-only
  runs emit so downstream joins keep every sample.
"""

import argparse
import csv
import json
import math
import re
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

# Interface metrics published alongside the per-sample TSVs. Monomers and
# structure-only models emit them as empty placeholders.
INTERFACE_SUFFIXES = ("_iptm.tsv", "_chainwise_iptm.tsv", "_ipsae.tsv", "_chainwise_ipsae.tsv")

# ColabFold2 backends publish their metrics under the shared 'colabfold2' model namespace (meta.model, pinned in workflows/colabfold2.nf).
COLABFOLD2_MODES = frozenset({
    "colabfold2-alphafold3", "colabfold2-boltz2", "esmfold2", "protenix2",
    "chai1", "intellifold2", "opendde", "openfold3", "openbind0", "rosettafold3",
})


# Backends reachable only behind the colabfold2- prefix, because the bare name selects an
# existing standalone mode. Kept in step with colabfold2_prefixed_models in main.nf.
COLABFOLD2_PREFIXED = ("alphafold3", "boltz2")

# Backends requested by their own name; the bare `esmfold2` here is upstream's JAX
# ESMFold2, distinct from the `esmfold` mode's esm-fold 1.0.3 PyTorch package.
COLABFOLD2_BARE = (
    "protenix2", "chai1", "intellifold2", "opendde", "openfold3", "openbind0",
    "rosettafold3", "esmfold2",
)
ESMFOLD2_RETIRED = {"esmfold2_lm300m", "esmfold2_lm600m"}


def resolve_mode_dir(outdir: Path, mode: str) -> Path:
    """Map a public mode token to its published output directory."""
    if mode in ESMFOLD2_RETIRED:
        raise ValueError(f"Retired ESMFold2 mode token: {mode}; use --mode esmfold2 with --esmfold2_model")
    if mode in {f"colabfold2-{backend}" for backend in COLABFOLD2_PREFIXED} or mode in COLABFOLD2_BARE:
        return outdir / mode
    return outdir / mode


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


def validate_plddt(path: Path, structure_only: bool = False) -> tuple[int, int, float | None]:
    rows = [line.split("\t") for line in path.read_text().splitlines()]
    assert len(rows) > 1, f"pLDDT file has no data rows: {path}"
    assert rows[0][0] == "Positions", f"Unexpected pLDDT header in {path}: {rows[0][0]}"
    values = []
    unavailable = 0
    for row in rows[1:]:
        assert len(row) == len(rows[0]), f"Inconsistent pLDDT column count in {path}"
        for cell in row[1:]:
            if cell == "n/a":
                # Structure-only models report no per-residue confidence; the pipeline publishes
                # literal n/a cells so the joins keep every sample.
                assert structure_only, f"pLDDT cell is 'n/a' without --structure-only: {path}"
                unavailable += 1
                continue
            try:
                value = float(cell)
            except ValueError:
                raise AssertionError(f"pLDDT value {cell!r} is not a number or 'n/a': {path}") from None
            assert math.isfinite(value) and 0 <= value <= 100, f"pLDDT values outside 0-100 or non-finite: {path}"
            values.append(value)
    assert values or unavailable, f"pLDDT file contains no scores: {path}"
    if structure_only:
        total_cells = len(values) + unavailable
        all_na = unavailable == total_cells
        all_zero_legacy = unavailable == 0 and bool(values) and all(value == 0 for value in values)
        assert all_na or all_zero_legacy, (
            f"Structure-only pLDDT must be entirely 'n/a' or all-zero legacy values: {path}"
        )
        return len(rows) - 1, total_cells, None
    mean_plddt = sum(values) / len(values)
    assert mean_plddt >= 5.0, f"Suspiciously low mean pLDDT: {path}"
    return len(rows) - 1, len(values), mean_plddt


def validate_pae(path: Path, structure_only: bool = False) -> tuple[int, int]:
    rows = [line.split("\t") for line in path.read_text().splitlines() if line]
    assert rows, f"Empty PAE matrix: {path}"
    assert all(len(row) == len(rows) for row in rows), f"PAE matrix is not square: {path}"
    if structure_only:
        # Structure-only models ship an all-NaN PAE by upstream design. Reject
        # finite values rather than accepting a merely square matrix.
        values = []
        for row in rows:
            for cell in row:
                try:
                    values.append(float(cell))
                except ValueError:
                    raise AssertionError(f"PAE value {cell!r} is not a number: {path}") from None
        assert values and all(math.isnan(value) for value in values), (
            f"Structure-only PAE must be all-NaN: {path}"
        )
        return len(rows), len(rows[0])
    values = [float(value) for row in rows for value in row]
    assert all(math.isfinite(value) and 0 <= value <= 31.75 for value in values), (
        f"PAE values outside 0-31.75 or non-finite: {path}"
    )
    return len(rows), len(rows[0])


def validate_multiqc_report(outdir: Path, mode: str, identifiers: list[str]) -> None:
    """Validate the rendered custom-content report and its exported data."""
    multiqc_dir = outdir / "multiqc"
    report = multiqc_dir / f"{mode}_multiqc_report.html"
    data_dir = multiqc_dir / f"{mode}_multiqc_report_data"
    plots_dir = multiqc_dir / f"{mode}_multiqc_report_plots"
    assert report.is_file(), f"MultiQC report missing: {report}"
    assert data_dir.is_dir(), f"MultiQC data directory missing: {data_dir}"
    assert plots_dir.is_dir(), f"MultiQC plots directory missing: {plots_dir}"

    data_path = data_dir / "multiqc_data.json"
    assert data_path.is_file(), f"MultiQC data JSON missing: {data_path}"
    data = json.loads(data_path.read_text())
    stats = data.get("report_general_stats_data", {}).get("custom_content", {})
    assert stats, "MultiQC general stats contain no ProteinFold custom content"
    sample_names = [name for name, row in stats.items() if row]
    for identifier in identifiers:
        assert any(name.startswith(f"{identifier}_") for name in sample_names), (
            f"No ProteinFold general-stats row for {identifier}; found {sample_names}"
        )
    assert not any("UNKNOWN" in name for name in sample_names), f"Unlabelled MultiQC rows: {sample_names}"

    rank_rows = [name for name in sample_names if re.search(r"[ _]rank_\d+$", name)]
    grouped_containers = [name for name, row in stats.items() if not row and "(grouped)" in name]
    if rank_rows:
        assert grouped_containers, (
            "MultiQC general stats contain rank rows but no nested groups; "
            "the table_sample_merge rank labels in assets/multiqc_config.yml are not taking effect"
        )

    plots = data.get("report_plot_data", {})
    lineplot = next((plot for plot in plots.values() if plot.get("id") == "proteinfold_plddt_lineplot"), None)
    assert lineplot is not None, "MultiQC data contain no ProteinFold pLDDT line plot"
    datasets = lineplot.get("datasets", [])
    assert datasets, "ProteinFold pLDDT line plot has no switcher datasets"
    dataset_labels = [dataset.get("label") for dataset in datasets]
    assert not any(label and "_rank_" in label for label in dataset_labels), (
        f"The pLDDT line-plot switcher must be per prediction, not per rank: {dataset_labels}"
    )
    for dataset in datasets:
        series_names = [line.get("name", "") for line in dataset.get("lines", [])]
        assert series_names, f"Empty pLDDT switcher dataset: {dataset.get('label')}"
        assert all(re.fullmatch(r"rank_\d+", name) for name in series_names), (
            f"pLDDT dataset {dataset.get('label')} must nest one rank_N series per ranked model, "
            f"got {series_names}"
        )
    print(f"Validated MultiQC: {report.name} ({len(sample_names)} ProteinFold rows, {len(datasets)} pLDDT datasets)")


def validate_detailed_report(outdir: Path, identifier: str) -> None:
    """Validate the embedded configuration of a per-protein report."""
    reports = sorted((outdir / "reports").glob(f"{identifier}_*_report.html"))
    assert reports, f"No detailed report for {identifier} in {outdir / 'reports'}"
    html = reports[0].read_text()
    match = re.search(r'<script type="application/json" id="report-config">(.*?)</script>', html, re.DOTALL)
    assert match, f"report-config JSON blob missing from {reports[0].name}"
    config = json.loads(match.group(1))
    assert config.get("sampleName") == identifier
    for key in ("programName", "models", "models_data", "lddt_averages"):
        assert config.get(key), f"report config is missing {key}"
    for key in ("iptm_scores", "ipsae_scores", "chainwise_iptm", "chainwise_ipsae"):
        assert key in config, f"report config is missing {key}"
    print(f"Validated detailed report: {reports[0].name}")


def validate_interface_metrics(path: Path) -> int:
    """Validate one interface-metric TSV (ipTM/ipSAE, flat or chain-wise).

    Flat files (``<id>_iptm.tsv`` / ``<id>_ipsae.tsv``) carry one
    ``<rank>\\t<score>`` row per model; chain-wise files add a rank-label
    header row (first cell empty) and one row per chain pair with the pair
    label in the first column. Scores are probabilities in [0, 1]; 'n/a'
    cells mark pairs a model did not score.
    """
    rows = [line.split("\t") for line in path.read_text().splitlines() if line]
    assert rows, f"Interface metric file has no rows: {path}"
    widths = {len(row) for row in rows}
    assert len(widths) == 1, f"Inconsistent interface metric column count in {path}: {sorted(widths)}"
    data_rows = [row for row in rows if row and row[0].strip()]
    assert data_rows, f"Interface metric file contains only a header row: {path}"
    checked = 0
    for row in data_rows:
        for cell in row[1:]:
            if cell == "n/a":
                continue
            try:
                value = float(cell)
            except ValueError:
                raise AssertionError(f"Interface score {cell!r} is not a number or 'n/a': {path}") from None
            assert math.isfinite(value) and 0 <= value <= 1, f"Interface score outside 0-1 or non-finite: {path}"
            checked += 1
    assert checked, f"Interface metric file contains no scores: {path}"
    return checked


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--extension", required=True, choices=[".pdb", ".cif", ".mmcif"])
    parser.add_argument("--outdir", required=True, type=Path)
    parser.add_argument("--samplesheet", required=True)
    parser.add_argument(
        "--structure-only",
        action="store_true",
        help="Model ships no confidence head (NO_CONFIDENCE_HEAD): accept n/a pLDDT "
        "cells without a mean-pLDDT gate and all-NaN PAE matrices.",
    )
    parser.add_argument(
        "--require-pae",
        action="store_true",
        help="Require one PAE matrix per input. Some prediction modes do not emit PAE.",
    )
    args = parser.parse_args()

    parser_canary()
    ids = input_ids(args.samplesheet)
    mode_dir = resolve_mode_dir(args.outdir, args.mode)
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
        position_count, score_count, mean_plddt = validate_plddt(path, structure_only=args.structure_only)
        if args.structure_only:
            print(
                f"Validated pLDDT: {path.name} "
                f"({position_count} positions, {score_count} cells; no confidence head identity verified)"
            )
        else:
            print(
                f"Validated pLDDT: {path.name} "
                f"({position_count} positions, {score_count} scores, mean={mean_plddt:.1f})"
            )

    pae_files = sorted(path for path in mode_dir.rglob("*.tsv") if path.parent.name == "paes")
    if args.require_pae:
        assert pae_files, f"{args.display_name} produced no PAE matrices"
        for identifier in ids:
            assert any(identifier in path.name for path in pae_files), (
                f"No {args.display_name} PAE matrix for input {identifier}"
            )
    for path in pae_files:
        row_count, column_count = validate_pae(path, structure_only=args.structure_only)
        print(f"Validated PAE: {path.name} ({row_count}x{column_count} matrix)")

    multiqc_model = "colabfold2" if args.mode in COLABFOLD2_MODES else args.mode
    validate_multiqc_report(args.outdir, multiqc_model, ids)
    for identifier in ids:
        validate_detailed_report(args.outdir, identifier)

    interface_files = sorted(
        path for path in mode_dir.rglob("*.tsv") if path.name.endswith(INTERFACE_SUFFIXES)
    )
    for path in interface_files:
        if path.stat().st_size == 0:
            print(f"Interface metrics empty (expected for monomer/structure-only runs): {path.name}")
            continue
        checked = validate_interface_metrics(path)
        print(f"Validated interface metrics: {path.name} ({checked} scores)")

    print(
        f"Validated {args.display_name}: {len(ids)} inputs, {len(structures)} structures, "
        f"{len(plddt_files)} pLDDT files, {len(pae_files)} PAE matrices, "
        f"{len(interface_files)} interface metric files"
    )


if __name__ == "__main__":
    main()
