#!/usr/bin/env python3
from plot_utils import (
    structure_to_pdb_string,
    reset_residue_numbers,
    sort_structures_by_rank,
    align_structures,
    plddt_from_struct_b_factor,
    generate_plddt_plot,
    generate_pae_plot,
    generate_sequence_coverage_plot,
)
import json
import argparse
<<<<<<< HEAD
import os
=======
import csv
import json
from matplotlib import pyplot as plt
import numpy as np
from collections import OrderedDict
import base64
import plotly.graph_objects as go
>>>>>>> origin/dev
import re
from pathlib import Path

<<<<<<< HEAD
prog_name_mapping = {
    "proteinfold": "ProteinFold",
=======
def is_missing_input(path, placeholder_prefix="NO_FILE"):
    return (
        not path
        or os.path.basename(path).startswith(placeholder_prefix)
        or not os.path.exists(path)
        or os.path.getsize(path) == 0
    )

def generate_pae_plot(pae_path, out_dir, name, save_image=False):
    #save_image=False because plotly needs a local install of Google Chrome to save images.....
    """
    Generate a Plotly heatmap for Predicted Aligned Error (PAE) data.

    Args:
        pae (2D array): The PAE matrix.
    Returns:
        fig: A Plotly figure object of the PAE heatmap in green color scale
    """
    pae = np.genfromtxt(pae_path, delimiter="\t")
    fig = go.Figure()

    # Add heatmap
    fig.add_trace(
        go.Heatmap(
            z=pae,
            colorscale="Greens_r",
            zmin=0,
            zmax=30,
        )
    )
    fig.update_layout(
        xaxis=dict(title="Scored Residue", minallowed=0, maxallowed=pae.shape[0]-1),
        yaxis=dict(title="Aligned Residue", minallowed=0, maxallowed=pae.shape[1]-1, autorange="reversed"),
        width=600,
        height=600,
    )

    if save_image:
            image_path = f"{out_dir}/{name+('_' if name else '')}PAE.png"
            fig.write_image(image_path, width=800, height=800)

    return fig

def generate_output_images(msa_path, plddt_data, name, out_dir, in_type, generate_tsv, pdb):
    msa = []
    if not is_missing_input(msa_path):
        with open(msa_path, "r") as in_file:
            for line in in_file:
                msa.append([int(x) for x in line.strip().split()])

        # Pad jagged MSAs to avoid shape errors in downstream plotting
        if msa:
            max_len = max(len(row) for row in msa)
            if any(len(row) != max_len for row in msa):
                msa = [row + [21] * (max_len - len(row)) for row in msa]

        seqid = []
        for sequence in msa:
            matches = [
                1.0 if first == other else 0.0 for first, other in zip(msa[0], sequence)
            ]
            seqid.append(sum(matches) / len(matches))

        seqid_sort = sorted(range(len(seqid)), key=seqid.__getitem__)

        non_gaps = []
        for sequence in msa:
            non_gaps.append(
                [float(num != 21) if num != 21 else float("nan") for num in sequence]
            )

        sorted_non_gaps = [non_gaps[i] for i in seqid_sort]
        final = []
        for sorted_seq, identity in zip(
            sorted_non_gaps, [seqid[i] for i in seqid_sort]
        ):
            final.append(
                [
                    value * identity if not isinstance(value, str) else value
                    for value in sorted_seq
                ]
            )

        xaxis_size = len(final[0])
        yaxis_size = len(final)

        # ##################################################################
        plt.figure(figsize=(16, 10), dpi=100)
        # ##################################################################
        plt.title("Sequence coverage", fontsize=30, pad=36)
        plt.imshow(
            final,
            interpolation="nearest",
            aspect="auto",
            cmap="rainbow_r",
            vmin=0,
            vmax=1,
            origin="lower",
            extent=(0, xaxis_size, 0, yaxis_size)
        )

        column_counts = [0] * len(msa[0])
        for col in range(len(msa[0])):
            for row in msa:
                if row[col] != 21:
                    column_counts[col] += 1

        plt.plot(column_counts, color="black")
        plt.xlim(0, len(msa[0]))
        plt.ylim(0, len(msa))

        plt.tick_params(axis="both", which="both", labelsize=18)

        cbar = plt.colorbar()
        cbar.set_label("Sequence identity to query", fontsize=24, labelpad=24)
        cbar.ax.tick_params(labelsize=18)
        plt.xlabel("Positions", fontsize=24, labelpad=24)
        plt.ylabel("Sequences", fontsize=24, labelpad=36)
        plt.savefig(f"{out_dir}/{name}_{in_type}_seq_coverage.png")

        # ##################################################################

    plddt_per_model = OrderedDict()
    output_data = plddt_data

    if generate_tsv == "y":
        for plddt_path in output_data:
            with open(plddt_path, "r") as in_file:
                plddt_per_model[os.path.basename(plddt_path)[:-4]] = [
                    float(x) for x in in_file.read().strip().split()
                ]
    else:
        for i, plddt_values_str in enumerate(output_data):
            plddt_per_model[i] = []
            plddt_per_model[i] = [float(x) for x in plddt_values_str.strip().split()]

    fig = go.Figure()
    for idx, (model_name, value_plddt) in enumerate(plddt_per_model.items()):
        rank_label = os.path.splitext(pdb[idx])[0]
        fig.add_trace(
            go.Scatter(
                x=list(range(len(value_plddt))),
                y=value_plddt,
                mode="lines",
                name=rank_label,
                text=[f"({i}, {value:.2f})" for i, value in enumerate(value_plddt)],
                hoverinfo="text",
            )
        )
    fig.update_layout(
        title=dict(text="Predicted LDDT per position", x=0.5, xanchor="center"),
        xaxis=dict(
            title="Positions", showline=True, linecolor="black", gridcolor="WhiteSmoke", minallowed=0, maxallowed=len(value_plddt)-1
        ),
        yaxis=dict(
            title="Predicted LDDT",
            range=[0, 100],
            fixedrange=True,
            showline=True,
            linecolor="black",
            gridcolor="WhiteSmoke",
        ),
        legend=dict(yanchor="bottom", y=0.02, xanchor="right", x=1, bordercolor="Black", borderwidth=1),
        plot_bgcolor="white",
        width=600,
        height=600,
        modebar_remove=["toImage", "zoomIn", "zoomOut"],
    )
    html_content = fig.to_html(
        full_html=False,
        include_plotlyjs="cdn",
        config={"displayModeBar": True, "displaylogo": False, "scrollZoom": True},
    )

    with open(
        f"{out_dir}/{name+('_' if name else '')}coverage_LDDT.html", "w"
    ) as out_file:
        out_file.write(html_content)

    if not is_missing_input(args.pae, "NO_FILE_PAE"):
        pae_fig = generate_pae_plot(args.pae, out_dir, name)
        pae_html_content = pae_fig.to_html(
            full_html=False,
            include_plotlyjs="cdn",
            config={"displayModeBar": True, "displaylogo": False, "scrollZoom": True},
        )
        with open(
            f"{out_dir}/{name+('_' if name else '')}PAE.html", "w"
        ) as pae_out_file:
            pae_out_file.write(pae_html_content)

def generate_plots(msa_path, plddt_paths, name, out_dir):
    msa = []
    with open(msa_path, "r") as in_file:
        for line in in_file:
            msa.append([int(x) for x in line.strip().split()])

    seqid = []
    for sequence in msa:
        matches = [
            1.0 if first == other else 0.0 for first, other in zip(msa[0], sequence)
        ]
        seqid.append(sum(matches) / len(matches))

    seqid_sort = sorted(range(len(seqid)), key=seqid.__getitem__)

    non_gaps = []
    for sequence in msa:
        non_gaps.append(
            [float(num != 21) if num != 21 else float("nan") for num in sequence]
        )

    sorted_non_gaps = [non_gaps[i] for i in seqid_sort]
    final = []
    for sorted_seq, identity in zip(sorted_non_gaps, [seqid[i] for i in seqid_sort]):
        final.append(
            [
                value * identity if not isinstance(value, str) else value
                for value in sorted_seq
            ]
        )

    # Plotting Sequence Coverage using Plotly
    fig = go.Figure()
    fig.add_trace(
        go.Heatmap(
            z=final,
            colorscale="Rainbow",
            zmin=0,
            zmax=1,
        )
    )
    fig.update_layout(
        title="Sequence coverage", xaxis_title="Positions", yaxis_title="Sequences"
    )
    # Save as interactive HTML instead of an image
    fig.savefig(f"{out_dir}/{name+('_' if name else '')}seq_coverage.png")

    # Plotting Predicted LDDT per position using Plotly
    plddt_per_model = OrderedDict()
    plddt_paths.sort()
    for plddt_path in plddt_paths:
        with open(plddt_path, "r") as in_file:
            plddt_per_model[os.path.basename(plddt_path)[:-4]] = [
                float(x) for x in in_file.read().strip().split()
            ]

    i = 0
    for model_name, value_plddt in plddt_per_model.items():
        fig = go.Figure()
        fig.add_trace(
            go.Scatter(
                x=list(range(len(value_plddt))),
                y=value_plddt,
                mode="lines",
                name=model_name,
            )
        )
        fig.update_layout(title="Predicted LDDT per Position")
        fig.savefig(f"{out_dir}/{name+('_' if name else '')}coverage_LDDT_{i}.png")
        i += 1



def get_structure_parser(struct_file):
    suffix = os.path.splitext(struct_file)[1].lower()
    if suffix == ".pdb":
        return PDB.PDBParser(QUIET=True)
    if suffix in [".cif", ".mmcif"]:
        return PDB.MMCIFParser(QUIET=True)
    raise NotImplementedError("Reporting only supported for .pdb, .cif and .mmcif filetypes")


def parse_structure(struct_file, structure_id):
    parser = get_structure_parser(struct_file)
    return parser.get_structure(structure_id, struct_file)


def get_atom_id(atom):
    residue = atom.get_parent()
    chain = residue.get_parent()
    return (chain.get_id(), residue.get_id(), atom.name)


def get_non_hydrogen_atoms_by_id(structure):
    return {
        get_atom_id(atom): atom
        for atom in structure.get_atoms()
        if atom.element != "H"
    }


def align_structures(structures):
    parsed_structures = [
        parse_structure(structure, f"Structure_{i}")
        for i, structure in enumerate(structures)
    ]
    ref_structure = parsed_structures[0]
    atom_maps = [get_non_hydrogen_atoms_by_id(structure) for structure in parsed_structures]
    common_atom_ids = set(atom_maps[0])

    for atom_map in atom_maps[1:]:
        common_atom_ids.intersection_update(atom_map)

    if not common_atom_ids:
        raise ValueError("No common non-hydrogen atoms found between structures.")

    ref_atom_ids = [atom_id for atom_id in atom_maps[0] if atom_id in common_atom_ids]
    ref_atoms = [atom_maps[0][atom_id] for atom_id in ref_atom_ids]
    super_imposer = PDB.Superimposer()
    aligned_structures = [ref_structure]

    for i, structure in enumerate(parsed_structures[1:], start=1):
        target_atoms = [atom_maps[i][atom_id] for atom_id in ref_atom_ids]
        super_imposer.set_atoms(ref_atoms, target_atoms)
        super_imposer.apply(structure.get_atoms())

        aligned_structure = f"aligned_structure_{i}.cif"
        io = PDB.MMCIFIO()
        io.set_structure(structure)
        io.save(aligned_structure)
        aligned_structures.append(aligned_structure)

    return aligned_structures


def pdb_to_lddt(struct_files, generate_tsv):
    struct_files_sorted = struct_files
    struct_files_sorted.sort()

    output_lddt = []
    averages = []

    for struct_file in struct_files_sorted:
        plddt_values = []

        structure = parse_structure(struct_file, "")

        for residue in structure.get_residues():
            res_pLDDT_tot = 0
            res_atom_count = 0

            for atom in residue.get_atoms():
                res_atom_count +=1
                res_pLDDT_tot += atom.get_bfactor()

            # Residue-level mean for ESMfold atom-level pLDDT
            res_pLDDT_ave = res_pLDDT_tot/res_atom_count

            if res_pLDDT_ave < 1.0:
                res_pLDDT_ave *= 100
            plddt_values.append(res_pLDDT_ave)

        # Calculate the average PLDDT value for the current file
        if plddt_values:
            avg_plddt = sum(plddt_values) / len(plddt_values)
            averages.append(round(avg_plddt, 3))
        else:
            averages.append(0.0)

        if generate_tsv == "y":
            output_file = f"{os.path.splitext(struct_file)[0]}_plddt.tsv"
            with open(output_file, "w") as outfile:
                outfile.write(" ".join(map(str, plddt_values)) + "\n")
            output_lddt.append(output_file)
        else:
            plddt_values_string = " ".join(map(str, plddt_values))
            output_lddt.append(plddt_values_string)

    return output_lddt, averages


def read_ranked_score_tsv(tsv_path, model_count):
    scores = ["n/a"] * model_count
    if is_missing_input(tsv_path):
        return scores

    rows = []
    with open(tsv_path, "r") as handle:
        reader = csv.reader(handle, delimiter="\t")
        for row in reader:
            if len(row) < 2:
                continue
            try:
                rank = int(row[0])
                score = float(row[1])
            except ValueError:
                continue
            rows.append((rank, f"{score:.3f}"))

    parsed_ranks = [rank for rank, _ in rows]
    rank_offset = 1 if parsed_ranks and 0 not in parsed_ranks and 1 in parsed_ranks else 0
    for rank, score in sorted(rows, key=lambda item: item[0]):
        rank -= rank_offset
        if 0 <= rank < model_count:
            scores[rank] = score

    return scores


def read_pair_score_tsv(tsv_path, model_count):
    scores = [{} for _ in range(model_count)]
    if is_missing_input(tsv_path):
        return scores

    with open(tsv_path, "r") as handle:
        reader = list(csv.reader(handle, delimiter="\t"))

    if not reader or len(reader[0]) < 2:
        return scores

    parsed_headers = []
    rank_headers = []
    for header in reader[0][1:]:
        try:
            parsed_rank = int(header)
            parsed_headers.append(parsed_rank)
            rank_headers.append(parsed_rank)
        except ValueError:
            rank_headers.append(None)

    rank_offset = 1 if parsed_headers and 0 not in parsed_headers and 1 in parsed_headers else 0

    for row in reader[1:]:
        if len(row) < 2:
            continue
        pair_label = row[0]
        for col_idx, value in enumerate(row[1:]):
            rank = rank_headers[col_idx] if col_idx < len(rank_headers) else None
            if rank is None:
                continue
            rank -= rank_offset
            if not (0 <= rank < model_count):
                continue
            try:
                scores[rank][pair_label] = f"{float(value):.4f}"
            except ValueError:
                continue

    return scores


def build_pair_score_matrices(score_maps):
    matrices = []

    for score_map in score_maps:
        if not score_map:
            matrices.append({"chains": [], "rows": []})
            continue

        chain_ids = sorted(
            {
                chain_id
                for pair_label in score_map.keys()
                for chain_id in pair_label.split(":")
                if ":" in pair_label
            }
        )
        rows = []
        for row_chain in chain_ids:
            row = []
            for col_chain in chain_ids:
                row.append(score_map.get(f"{row_chain}:{col_chain}", ""))
            rows.append(row)

        matrices.append({"chains": chain_ids, "rows": rows})

    return matrices


print("Starting...")

version = "1.0.0"
model_name = {
    "esmfold": "ESMFold",
>>>>>>> origin/dev
    "alphafold2": "AlphaFold2",
    "alphafold3": "AlphaFold3",
    "esmfold": "ESMFold",
    "colabfold": "ColabFold",
<<<<<<< HEAD
    "rosettafold-all-atom": "RoseTTAFold-All-Atom",
    "rosettafold2na": "RoseTTAFold2NA",
    "helixfold3": "HelixFold3",
    "boltz": "Boltz",
    "comparison": "Comparison",
}

def _tool_program_label(structure_path):
    basename = Path(structure_path).stem.lower()
    for key, label in prog_name_mapping.items():
        if key not in ("comparison", "proteinfold") and key in basename:
            return label
    # If no specific tool is detected, return the base filename as a fallback (without extension)
    return Path(structure_path).stem
=======
    "boltz": "Boltz"
}

parser = argparse.ArgumentParser()
parser.add_argument("--type", dest="in_type")
parser.add_argument(
    "--generate_tsv", choices=["y", "n"], default="n", dest="generate_tsv"
)
parser.add_argument("--msa", dest="msa", default="NO_FILE")
parser.add_argument("--pdb", dest="pdb", required=True, nargs="+")
parser.add_argument("--pae", dest="pae", default="NO_FILE")
parser.add_argument("--iptm", dest="iptm", default="NO_FILE")
parser.add_argument("--ipsae", dest="ipsae", default="NO_FILE")
parser.add_argument("--chainwise_iptm", dest="chainwise_iptm", default="NO_FILE")
parser.add_argument("--chainwise_ipsae", dest="chainwise_ipsae", default="NO_FILE")
parser.add_argument("--name", dest="name")
parser.add_argument("--output_dir", dest="output_dir")
parser.add_argument("--html_template", dest="html_template")
parser.add_argument("--version", action="version", version=f"{version}")
parser.set_defaults(output_dir="")
parser.set_defaults(in_type="esmfold")
parser.set_defaults(name="")
args = parser.parse_args()
>>>>>>> origin/dev

def generate_report(name, out_dir, structures, msa_files, pae_files, prog, report_type, html_template, num_structs_limit=5):

    PLOTLY_CONFIG = {"displayModeBar": True, "displaylogo": False, "scrollZoom": True}

<<<<<<< HEAD
    # Sort structures by name and limit to set number
    # For comparison report using single top ranked structure from each tool so sorting not performed - structures should be pre-sorted and limited by user input
    if report_type != "comparison" and len(structures) > num_structs_limit:
        print(f"Warning: More than {num_structs_limit} structures provided. Sorting and using only the first {num_structs_limit} structures.")
        sorted_structures = sort_structures_by_rank(structures, prog)
        structures = sorted_structures[:num_structs_limit]

    # Keep original file paths for reading structure data and NGL viewer
    structure_paths = list(structures)
=======
print("generating html report...")
structures = args.pdb
structures.sort() #TODO: make sure sorting here doesnt break rank order
iptm_scores = read_ranked_score_tsv(args.iptm, len(structures))
ipsae_scores = read_ranked_score_tsv(args.ipsae, len(structures))
chainwise_iptm_scores = read_pair_score_tsv(args.chainwise_iptm, len(structures))
chainwise_ipsae_scores = read_pair_score_tsv(args.chainwise_ipsae, len(structures))
chainwise_iptm_matrices = build_pair_score_matrices(chainwise_iptm_scores)
chainwise_ipsae_matrices = build_pair_score_matrices(chainwise_ipsae_scores)
aligned_structures = align_structures(structures)

io = PDB.MMCIFIO()
ref_structure_path = "aligned_structure_0.cif"
io.set_structure(aligned_structures[0])
io.save(ref_structure_path)
aligned_structures[0] = ref_structure_path
>>>>>>> origin/dev

    # Use PDB format for NGL viewer convenience. Since I'm parsing BioPython objects I can force format from object regardless of input file type
    struct_format = "pdb"

<<<<<<< HEAD
    # Parse structures into BioPython objects with sequential residue numbering
    # (ESMFold, HF3 etc. restart numbering per chain — renumber to be sequential)
    parsed_structures = [reset_residue_numbers(s) for s in structure_paths]
=======
model_names = [
    f"{os.path.splitext(model)[0]}.cif"
    for model in structures
]
args_pdb_array_js = ",\n".join([f'"{model}"' for model in model_names])
proteinfold_template = re.sub(
    r"const MODELS = \[.*?\];",  # Match the existing MODELS array in HTML template
    f"const MODELS = [\n  {args_pdb_array_js}\n];",  # Replace with the new array
    proteinfold_template,
    flags=re.DOTALL,
)
>>>>>>> origin/dev

    # For comparison mode, re-parse and align structures
    if report_type == "comparison":
        parsed_structures = align_structures(structure_paths)

<<<<<<< HEAD
    print("Structures:", structure_paths)


    # Build model labels: infer tool names for comparison, rank numbers otherwise
    if report_type == "comparison":
        model_labels = [_tool_program_label(s) for s in structure_paths]
    else:
        model_labels = [f"Rank {idx+1}" for idx, _ in enumerate(parsed_structures)]


    # Read HTML template
    with open(html_template, "r") as f:
        html = f.read()

    # Build configuration JSON for JavaScript
    config = {
        "reportType": report_type,
        "sampleName": name,
        "programName": prog_name_mapping.get(prog, prog),
        "structFormat": struct_format,
        "models": model_labels,
        "plddtAverages": [round(plddt_from_struct_b_factor(s).mean(), 2) for s in parsed_structures],
        "modelsData": [structure_to_pdb_string(s) for s in parsed_structures],
    }

    # Inject configuration as a JSON script tag before </head>
    config_script = f'<script type="application/json" id="report-config">{json.dumps(config)}</script>'
    html = html.replace('</head>', f'{config_script}\n</head>', 1)

    # Generate sequence coverage plot from first MSA file
    seq_cov_html = None
    if msa_files:
        # Filter out tools that don't generate MSAs (e.g. ESMFold) - if MSA file is a dummy placeholder, skip the section entirely

        valid_msa = [(m, _tool_program_label(m)) for m in msa_files if not os.path.basename(m).startswith("DUMMY_")]

        if valid_msa:
            seq_cov_sections = []
            for msa_file, tool_label in valid_msa:
                seq_cov_fig = generate_sequence_coverage_plot(msa_file)
                # In comparison mode, label each coverage plot with its tool name
                if report_type == "comparison" and len(valid_msa) > 1:
                    seq_cov_fig.update_layout(
                        title=dict(text=f"Sequence Coverage — {tool_label}")
                    )
                seq_cov_sections.append(
                    seq_cov_fig.to_html(
                        full_html=False,
                        include_plotlyjs="cdn",
                        config=PLOTLY_CONFIG,
                    )
                )
            seq_cov_html = "\n".join(seq_cov_sections)

    # Replace or remove optional sections
    if seq_cov_html:
        html = html.replace('<div id="seq_cov_placeholder"></div>', seq_cov_html, 1)
    else:
        html = re.sub(r'<!-- BEGIN_MSA_SECTION -->.*?<!-- END_MSA_SECTION -->', '', html, flags=re.DOTALL)

    # Generate the pLDDT plot and convert to HTML
    plddt_fig = generate_plddt_plot(parsed_structures, labels=model_labels)
    plddt_html = plddt_fig.to_html(
        full_html=False,
        include_plotlyjs="cdn",
        config=PLOTLY_CONFIG,
=======
iptm_js_array = f"const IPTM_SCORES = {iptm_scores};"
proteinfold_template = proteinfold_template.replace(
    "const IPTM_SCORES = [];", iptm_js_array
)

ipsae_js_array = f"const IPSAE_SCORES = {ipsae_scores};"
proteinfold_template = proteinfold_template.replace(
    "const IPSAE_SCORES = [];", ipsae_js_array
)

chainwise_iptm_js_array = f"const CHAINWISE_IPTM_SCORES = {json.dumps(chainwise_iptm_matrices)};"
proteinfold_template = proteinfold_template.replace(
    "const CHAINWISE_IPTM_SCORES = [];", chainwise_iptm_js_array
)

chainwise_ipsae_js_array = f"const CHAINWISE_IPSAE_SCORES = {json.dumps(chainwise_ipsae_matrices)};"
proteinfold_template = proteinfold_template.replace(
    "const CHAINWISE_IPSAE_SCORES = [];", chainwise_ipsae_js_array
)

i = 0
for structure in aligned_structures:
    proteinfold_template = proteinfold_template.replace(
        f"*_data_ranked_{i}.cif*", open(structure, "r").read().replace("\n", "\\n")
>>>>>>> origin/dev
    )
    html = html.replace('<div id="plddt_placeholder"></div>', plddt_html, 1)

<<<<<<< HEAD
    # Generate PAE plot from first PAE file (TODO: toggle PAE with model selection), Not used in comparison report
    if pae_files:
        pae_fig = generate_pae_plot(pae_files[0])
        pae_html = pae_fig.to_html(
            full_html=False,
            include_plotlyjs="cdn",
            config=PLOTLY_CONFIG,
=======
if not is_missing_input(args.msa):
    image_path = f"{args.output_dir}/{args.name}_{args.in_type}_seq_coverage.png"
    with open(image_path, "rb") as in_file:
        proteinfold_template = proteinfold_template.replace(
            "seq_coverage.png",
            f"data:image/png;base64,{base64.b64encode(in_file.read()).decode('utf-8')}",
>>>>>>> origin/dev
        )
        html = html.replace('<div id="pae_placeholder"></div>', pae_html, 1)
    else:
        html = re.sub(r'<!-- BEGIN_PAE_SECTION -->.*?<!-- END_PAE_SECTION -->', '', html, flags=re.DOTALL)

    # Write the final HTML report
    with open(f"{out_dir}/{name}_{report_type}_report.html", "w") as out_file:
        out_file.write(html)

def main():
    parser = argparse.ArgumentParser(description="Generate protein structure reports.")
    parser.add_argument("--name", required=True, help="Name of the report.")
    parser.add_argument("--output_dir", required=True, help="Output directory for the report.")
    parser.add_argument("--structs", required=True, nargs="+", help="List of structure file paths (.pdb or .cif).")
    parser.add_argument("--msa", nargs="+", default=None, help="MSA file path(s).")
    parser.add_argument("--pae", nargs="+", default=None, help="PAE file path(s).")
    parser.add_argument("--prog", default="proteinfold", choices=["proteinfold", "alphafold2", "alphafold3", "esmfold", "colabfold", "rosettafold-all-atom", "rosettafold2na", "helixfold3", "boltz", "comparison"], type=str.lower, help="The program used to generate the structures.")
    parser.add_argument("--report_type", default="standard", choices=["standard", "comparison"], help="The type of report to generate.")
    parser.add_argument("--html_template", required=True, help="Path to the HTML report template.")

    args = parser.parse_args()

    print("Generating report.....")

    html_template = args.html_template

    ## Both these values could be missing - ESMFold for MSA, many others for PAE
    #if args.msa and os.path.basename(args.msa[0]).startswith("DUMMY_"):
    #    args.msa = None
    #if args.pae and os.path.basename(args.pae[0]).startswith("DUMMY_"):
    #    args.pae = None
    ## But caught by a more broad catch-all below for any future metrics, just MSA and PAE are the most explicit cases so left as examples
    for attr in vars(args):
        val = getattr(args, attr)
        if isinstance(val, list) and val and os.path.basename(val[0]).startswith("DUMMY_"):
            setattr(args, attr, None)

    generate_report(
        name=args.name,
        out_dir=args.output_dir,
        structures=args.structs,
        num_structs_limit=5,
        msa_files=args.msa,
        pae_files=args.pae,
        prog=args.prog,
        report_type=args.report_type,
        html_template=html_template,
    )

<<<<<<< HEAD
if __name__ == "__main__":
    main()
=======
if not is_missing_input(args.pae, "NO_FILE_PAE"):
    with open(
        f"{args.output_dir}/{args.name + ('_' if args.name else '')}PAE.html",
        "r",
    ) as pae_in_file:
        pae_html = pae_in_file.read()
        proteinfold_template = proteinfold_template.replace(
            '<div id="pae_placeholder"></div>', pae_html
        )
else:
    pattern = r'<div id="pae_container".*?>.*?(<!--.*?-->.*?)*?</div>\s*</div>'
    proteinfold_template = re.sub(pattern, "", proteinfold_template, flags=re.DOTALL)

with open(
    f"{args.output_dir}/{args.name}_{args.in_type.lower()}_report.html", "w"
) as out_file:
    out_file.write(proteinfold_template)
>>>>>>> origin/dev
