#!/usr/bin/env python3
"""
Extract metrics from Protenix prediction outputs for MultiQC reporting.

Protenix outputs:
  - .cif structure files with pLDDT in B-factor column
  - _summary_confidence_*.json with plddt, ptm, iptm, pae, ranking_score

Usage:
    protenix_extract_metrics.py --name <SAMPLE_ID> --out_dir <PROTENIX_OUTPUT>
"""

import argparse
import csv
import glob
import json
import os
import sys

import numpy as np


def write_tsv(file_path, rows):
    with open(file_path, "w") as f:
        writer = csv.writer(f, delimiter="\t")
        writer.writerows(rows)


def format_pae_rows(pae_data):
    return [[f"{num:.4f}" for num in row] for row in pae_data]


def extract_metrics(name, out_dir):
    """Extract pLDDT, pTM, iPTM, and PAE from Protenix output."""
    # Find all confidence JSON files
    confidence_files = sorted(
        glob.glob(os.path.join(out_dir, "**", "*_summary_confidence_*.json"), recursive=True)
    )

    if not confidence_files:
        print(f"Warning: No confidence files found in {out_dir}", file=sys.stderr)
        return

    ptm_data = {}
    iptm_data = {}

    for idx, conf_file in enumerate(confidence_files):
        with open(conf_file, "r") as f:
            data = json.load(f)

        model_id = idx

        # Extract pLDDT
        if "plddt" in data and idx == 0:
            # Per-residue pLDDT for the top-ranked model
            plddt_values = data["plddt"]
            if isinstance(plddt_values, list):
                plddt_rows = [["Positions"] + [f"rank_{i}" for i in range(len(confidence_files))]]
                # We'll fill in rank_0 now and others in the loop
                for res_idx, val in enumerate(plddt_values):
                    plddt_rows.append([res_idx, f"{val:.2f}"])

        # Extract PAE
        if "pae" in data:
            write_tsv(f"{name}_{model_id}_pae.tsv", format_pae_rows(data["pae"]))

        # Extract pTM
        if "ptm" in data and data["ptm"] is not None:
            ptm_data[model_id] = f"{np.round(data['ptm'], 3)}"

        # Extract iPTM
        if "iptm" in data and data["iptm"] is not None:
            iptm_data[model_id] = f"{np.round(data['iptm'], 3)}"

    # Build pLDDT TSV from all confidence files
    all_plddts = []
    for conf_file in confidence_files:
        with open(conf_file, "r") as f:
            data = json.load(f)
        if "plddt" in data and isinstance(data["plddt"], list):
            all_plddts.append(data["plddt"])

    if all_plddts:
        n_res = len(all_plddts[0])
        rank_names = [f"rank_{i}" for i in range(len(all_plddts))]
        plddt_rows = [["Positions"] + rank_names]
        for res_idx in range(n_res):
            row = [res_idx]
            for plddt_list in all_plddts:
                if res_idx < len(plddt_list):
                    row.append(f"{plddt_list[res_idx]:.2f}")
                else:
                    row.append("0.00")
            plddt_rows.append(row)
        write_tsv(f"{name}_plddt.tsv", plddt_rows)

    # Write pTM
    if ptm_data:
        ptm_rows = sorted([[k, v] for k, v in ptm_data.items()], key=lambda x: x[0])
        write_tsv(f"{name}_ptm.tsv", ptm_rows)

    # Write iPTM
    if iptm_data:
        iptm_rows = sorted([[k, v] for k, v in iptm_data.items()], key=lambda x: x[0])
        write_tsv(f"{name}_iptm.tsv", iptm_rows)

    # Write chainwise pTM and iPTM if available
    for idx, conf_file in enumerate(confidence_files):
        with open(conf_file, "r") as f:
            data = json.load(f)
        if "chain_pair_iptm" in data and data["chain_pair_iptm"] is not None:
            matrix = np.array(data["chain_pair_iptm"])
            # Extract off-diagonal (iPTM) and diagonal (pTM) elements
            chainwise_iptm = []
            chainwise_ptm = []
            for i in range(matrix.shape[0]):
                for j in range(matrix.shape[1]):
                    if i != j:
                        chainwise_iptm.append(f"{matrix[i][j]:.4f}")
                    else:
                        chainwise_ptm.append(f"{matrix[i][j]:.4f}")
            if chainwise_ptm:
                write_tsv(f"{name}_chainwise_ptm.tsv", [chainwise_ptm])
            if chainwise_iptm:
                write_tsv(f"{name}_chainwise_iptm.tsv", [chainwise_iptm])
            break  # Only top-ranked


def main():
    parser = argparse.ArgumentParser(
        description="Extract metrics from Protenix output"
    )
    parser.add_argument("--name", required=True, help="Sample identifier")
    parser.add_argument("--out_dir", required=True, help="Protenix output directory")
    args = parser.parse_args()

    extract_metrics(args.name, args.out_dir)


if __name__ == "__main__":
    main()
