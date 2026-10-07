#!/usr/bin/env python3
"""Generate MultiQC custom content for one prediction mode.

Reads the routed metric TSVs and writes proteinfold_<mode>_generalstats_mqc.json
and proteinfold_<mode>_plddt_lineplot_mqc.json for the stock MULTIQC module.
"""

import argparse
import csv
import json
import math
import re
import sys
from pathlib import Path

MODE_LABELS = {
    "alphafold2": "AlphaFold2",
    "alphafold3": "AlphaFold3",
    "colabfold": "ColabFold",
    "esmfold": "ESMFold",
    "boltz": "Boltz",
}

ROUTED_SUFFIXES = ("_plddt", "_msa", "_iptm", "_ptm")

RANK_COLUMN_RE = re.compile(r"^rank_(\d+)$")




def warn(message):
    """Print a warning to stderr; warnings never abort the report."""
    print(f"WARNING: {message}", file=sys.stderr)


def fail(message):
    """Print an error and exit non-zero (pipeline wiring problems only)."""
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(2)


def clean_float(value):
    """Return a finite float, or None for missing/NaN/infinite values."""
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) else None


def classify_metric(filename):
    """Map a metric file name to a routed metric, or None if not summarised."""
    is_chainwise = "_chainwise_" in filename
    if filename.endswith("_plddt.tsv"):
        return None if is_chainwise else "plddt"
    if filename.endswith("_msa.tsv"):
        return None if is_chainwise else "msa"
    if filename.endswith("_iptm.tsv") and not filename.endswith("_chainwise_iptm.tsv"):
        return "iptm"
    if filename.endswith("_ptm.tsv") and not filename.endswith("_chainwise_ptm.tsv"):
        return "ptm"
    return None


def sample_id_from_fn(filename, model_key):
    """Derive the sample id from a routed metric file name.

    Strips the metric suffix and, for MSA files, the prediction-mode infix the
    extractors bake into ``<id>_<mode>_msa.tsv``. The result is the sample id
    shared by every metric of one prediction.
    """
    stem = filename[:-4] if filename.lower().endswith(".tsv") else filename
    for suffix in ROUTED_SUFFIXES:
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    else:
        return None
    if filename.endswith("_msa.tsv"):
        infix = f"_{model_key}"
        if stem.endswith(infix):
            stem = stem[: -len(infix)]
    return stem


def set_metric(rows, sample_name, column, value, source):
    """Set a metric, warning on duplicate-id collapse (the samplesheet does not enforce unique ids)."""
    if column in rows.setdefault(sample_name, {}):
        warn(
            f"Duplicate sample data: '{sample_name}' already has '{column}' values; "
            f"values from {Path(source).name} overwrite the earlier file. "
            "The input samplesheet schema does not enforce unique ids."
        )
    rows[sample_name][column] = value


def parse_plddt(filepath, sample_name, rows, line_series):
    """Per-rank mean pLDDT plus per-residue series; the parent row is the top-ranked model."""
    with open(filepath, newline="") as handle:
        table = [row for row in csv.reader(handle, delimiter="\t") if row]
    if not table:
        warn(f"pLDDT file {filepath.name} is empty; skipping")
        return
    header, data_rows = table[0], table[1:]
    if len(header) < 2 or str(header[0]).strip().lower() != "positions":
        warn(f"pLDDT file {filepath.name} has no 'Positions' header column; skipping")
        return

    rank_cols = []
    seen_ranks = set()
    for index, column in enumerate(header[1:]):
        match = RANK_COLUMN_RE.match(str(column).strip())
        if match and match.group(1) not in seen_ranks:
            rank_cols.append((index + 1, match.group(1)))
            seen_ranks.add(match.group(1))
        elif match:
            warn(f"pLDDT file {filepath.name}: ignoring duplicate column '{column}'")
        else:
            warn(f"pLDDT file {filepath.name}: ignoring unexpected column '{column}'")
    if not rank_cols:
        warn(f"pLDDT file {filepath.name} has no rank_ columns; skipping")
        return

    rank_means = {}
    rank_points = {}
    bad_positions = 0
    for index, rank_num in rank_cols:
        points = []
        values = []
        for row in data_rows:
            if index >= len(row):
                continue
            try:
                position = int(str(row[0]).strip())
            except (TypeError, ValueError):
                bad_positions += 1
                continue
            value = clean_float(row[index])
            if value is None:
                continue  # drop NaN/inf: they must not reach the JSON output
            points.append([position, value])
            values.append(value)
        if points:
            points.sort(key=lambda point: point[0])
            rank_points[rank_num] = points
        if values:
            rank_means[rank_num] = sum(values) / len(values)
    if bad_positions:
        warn(f"pLDDT file {filepath.name}: ignored {bad_positions} row(s) with non-integer positions")

    if not rank_means:
        warn(f"pLDDT file {filepath.name} yielded no usable rank values; skipping")
        return

    top_rank = min(rank_means, key=int)
    set_metric(rows, sample_name, "mean_plddt", rank_means[top_rank], filepath)
    for rank_num, mean in rank_means.items():
        if rank_num == top_rank:
            continue
        set_metric(rows, f"{sample_name}_rank_{rank_num}", "mean_plddt", mean, filepath)
    if rank_points:
        line_series.setdefault(sample_name, {})
        for rank_num, points in rank_points.items():
            line_series[sample_name][f"rank_{rank_num}"] = points


def parse_ranked_score(filepath, sample_name, metric, rows):
    """Header-less two-column (rank, value) score files such as ipTM / pTM.

    The parent row carries the top-ranked (numerically lowest) model's score;
    every other rank becomes a ``<sample>_rank_N`` sub-sample row.
    """
    scores = {}
    with open(filepath, newline="") as handle:
        for fields in csv.reader(handle, delimiter="\t"):
            if len(fields) < 2:
                continue
            value = clean_float(fields[1])
            if value is None:
                continue
            try:
                rank = int(str(fields[0]).strip())
            except (TypeError, ValueError):
                continue  # non-integer rows are not rank rows
            scores[rank] = value
    if not scores:
        warn(f"{metric} file {filepath.name} yielded no usable values; skipping")
        return

    top_rank = min(scores)
    set_metric(rows, sample_name, metric, scores[top_rank], filepath)
    for rank, value in scores.items():
        if rank == top_rank:
            continue
        set_metric(rows, f"{sample_name}_rank_{rank}", metric, value, filepath)


def parse_msa(filepath, sample_name, rows):
    """MSA depth: the number of sequence rows in ``<id>[_<mode>]_msa.tsv``."""
    with open(filepath) as handle:
        depth = sum(1 for line in handle if line.strip())
    if depth == 0:
        warn(f"MSA file {filepath.name} is empty; skipping")
        return
    set_metric(rows, sample_name, "msa_depth", depth, filepath)


GENERALSTATS_HEADERS = {
    "msa_depth": {
        "title": "Related sequence depth (MSA)",
        "description": "The number of related sequences (across the whole protein) that could be retrieved from the "
        "MSA (Multiple Sequence Alignment) stage",
        "namespace": "proteinfold",
        "format": "{:,.0f}",
    },
    "mean_plddt": {
        "title": "Structure confidence (average pLDDT)",
        "description": "Structure prediction confidence score across all residues in the top ranked protein "
        "structure - from the mean pLDDT (predicted Local Distance Difference Test) value",
        "namespace": "proteinfold",
        "max": 100,
        "min": 0,
        "cond_formatting_rules": {
            "very-low": [{"lt": 50}],
            "low": [{"gt": 50}, {"lt": 70}],
            "high": [{"gt": 70}, {"lt": 90}],
            "very-high": [{"gt": 90}],
        },
        "cond_formatting_colours": [
            {"very-low": "#f0743e"},
            {"low": "#f9d613"},
            {"high": "#60c2e8"},
            {"very-high": "#014ecc"},
        ],
    },
    "iptm": {
        "title": "Interface accuracy (ipTM)",
        "description": "Accuracy of the relative positions of two protein subunits from a multimer calculation - "
        "from the ipTM (interface predicted Template Modelling) score",
        "namespace": "proteinfold",
        "max": 1,
        "min": 0,
        "format": "{:,.2f}",
        "scale": "Purples",
    },
    "ptm": {
        "title": "Global accuracy (TM)",
        "description": "Global accuracy of the protein folded, less sensitive to localised inaccuracies than raw 3D "
        "atomic deviations (RMSD) - from the pTM (predicted Template Modelling) score",
        "namespace": "proteinfold",
        "max": 1,
        "min": 0,
        "format": "{:,.2f}",
        "scale": "Blues",
    },
}

LINEGRAPH_PCONFIG = {
    "id": "proteinfold_plddt_lineplot",
    "title": "ProteinFold: pLDDT by Position",
    "xlab": "Residue Position",
    "ylab": "pLDDT Score",
    "ymin": 0,
    "ymax": 100,
}


def dump_json(path, payload):
    """Write JSON, refusing to emit NaN/Infinity tokens (allow_nan=False)."""
    with open(path, "w") as handle:
        json.dump(payload, handle, indent=2, allow_nan=False, sort_keys=False)
        handle.write("\n")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Generate MultiQC custom-content JSON from proteinfold metric TSVs."
    )
    parser.add_argument(
        "--model",
        required=True,
        help="Prediction-mode key from the pipeline meta map (e.g. alphafold2, boltz); "
        "sample names are qualified with this mode, never with 'UNKNOWN'.",
    )
    parser.add_argument("--output-dir", default=".", help="Directory to write the *_mqc.json files into")
    parser.add_argument("metric_files", nargs="+", help="Routed metric TSVs (_plddt/_msa/_ptm/_iptm)")
    args = parser.parse_args(argv)

    model_key = (args.model or "").strip()
    if not model_key:
        fail("No prediction mode given (--model); refusing to emit '_UNKNOWN' sample names")
    mode_label = MODE_LABELS.get(model_key, model_key)

    rows = {}
    line_series = {}
    parsed_files = 0
    for raw_path in args.metric_files:
        filepath = Path(raw_path)
        metric = classify_metric(filepath.name)
        if metric is None:
            warn(
                f"{filepath.name}: not a summarised metric (PAE/ipSAE/chainwise or unknown); "
                "it stays in the detailed GENERATE_REPORT viewer and produces no bulk rows"
            )
            continue
        sample_id = sample_id_from_fn(filepath.name, model_key)
        if not sample_id:
            warn(f"Could not derive a sample id from {filepath.name}; skipping")
            continue
        sample_name = f"{sample_id}_{mode_label}"
        if metric == "plddt":
            parse_plddt(filepath, sample_name, rows, line_series)
        elif metric == "msa":
            parse_msa(filepath, sample_name, rows)
        else:
            parse_ranked_score(filepath, sample_name, metric, rows)
        parsed_files += 1

    if not args.metric_files:
        fail("No metric files were passed; the MULTIQC input channel is miswired")
    if parsed_files == 0:
        fail("None of the input files matched a routed metric (_plddt/_msa/_ptm/_iptm); the MULTIQC input channel is miswired")

    metrics_seen = {column for data in rows.values() for column in data}
    headers = {column: dict(GENERALSTATS_HEADERS[column]) for column in GENERALSTATS_HEADERS if column in metrics_seen}
    generalstats = {
        "id": "proteinfold",
        "section_name": "ProteinFold",
        "description": "Summary metrics for protein structure prediction "
        "(average pLDDT, MSA depth, pTM and ipTM per prediction)",
        "plot_type": "generalstats",
        "headers": headers,
        "data": rows,
    }

    datasets = []
    data_labels = []
    for sample_name in sorted(line_series):
        if not line_series[sample_name]:
            continue
        datasets.append(line_series[sample_name])
        data_labels.append({"name": sample_name, "ylab": "pLDDT score"})

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    generalstats_path = output_dir / f"proteinfold_{model_key}_generalstats_mqc.json"
    dump_json(generalstats_path, generalstats)

    linegraph_path = None
    if datasets:
        pconfig = dict(LINEGRAPH_PCONFIG)
        pconfig["data_labels"] = data_labels
        linegraph = {
            "id": "proteinfold_plddt_lineplot",
            "section_name": "ProteinFold: pLDDT by Position",
            "description": "Per-residue confidence scores across all predicted ranks "
            "(switch between predictions with the tabs above the plot)",
            "plot_type": "linegraph",
            "pconfig": pconfig,
            "data": datasets,
        }
        linegraph_path = output_dir / f"proteinfold_{model_key}_plddt_lineplot_mqc.json"
        dump_json(linegraph_path, linegraph)

    if linegraph_path is None:
        print(
            f"Generated {generalstats_path.name} from {parsed_files} metric file(s): "
            f"{len(rows)} sample row(s), no per-residue pLDDT series"
        )
    else:
        print(
            f"Generated {generalstats_path.name} and {linegraph_path.name} "
            f"from {parsed_files} metric file(s): {len(rows)} sample row(s), "
            f"{len(datasets)} pLDDT dataset(s), "
            f"metrics seen: {', '.join(sorted(metrics_seen)) or 'none'}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
