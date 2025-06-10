#!/usr/bin/env python

import os
import argparse
from matplotlib import pyplot as plt
from collections import OrderedDict
import base64
import plotly.graph_objects as go
import re
from Bio import PDB


def generate_output_images(msa_path, plddt_data, name, out_dir, in_type, generate_tsv, pdb):
    msa = []
    if in_type.lower() != "colabfold" and not msa_path.endswith("NO_FILE"):
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
        for sorted_seq, identity in zip(
            sorted_non_gaps, [seqid[i] for i in seqid_sort]
        ):
            final.append(
                [
                    value * identity if not isinstance(value, str) else value
                    for value in sorted_seq
                ]
            )

        # ##################################################################
        plt.figure(figsize=(14, 14), dpi=100)
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
        )

        column_counts = [0] * len(msa[0])
        for col in range(len(msa[0])):
            for row in msa:
                if row[col] != 21:
                    column_counts[col] += 1

        plt.plot(column_counts, color="black")
        plt.xlim(-0.5, len(msa[0]) - 0.5)
        plt.ylim(-0.5, len(msa) - 0.5)

        plt.tick_params(axis="both", which="both", labelsize=18)

        cbar = plt.colorbar()
        cbar.set_label("Sequence identity to query", fontsize=24, labelpad=24)
        cbar.ax.tick_params(labelsize=18)
        plt.xlabel("Positions", fontsize=24, labelpad=24)
        plt.ylabel("Sequences", fontsize=24, labelpad=36)
        plt.savefig(f"{out_dir}/{name+('_' if name else '')}seq_coverage.png")

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
            title="Positions", showline=True, linecolor="black", gridcolor="WhiteSmoke"
        ),
        yaxis=dict(
            title="Predicted LDDT",
            range=[0, 100],
            minallowed=0,
            maxallowed=100,
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



def align_structures(structures):
    parser = PDB.PDBParser(QUIET=True)
    structures = [
        parser.get_structure(f"Structure_{i}", pdb) for i, pdb in enumerate(structures)
    ]
    ref_structure = structures[0]

    common_atoms = set(
        f"{atom.get_parent().get_id()[1]}-{atom.name}"
        for atom in ref_structure.get_atoms()
    )
    for i, structure in enumerate(structures[1:], start=1):
        common_atoms = common_atoms.intersection(
            set(
                f"{atom.get_parent().get_id()[1]}-{atom.name}"
                for atom in structure.get_atoms()
            )
        )

    ref_atoms = [
        atom
        for atom in ref_structure.get_atoms()
        if f"{atom.get_parent().get_id()[1]}-{atom.name}" in common_atoms
    ]
    # print(ref_atoms)
    super_imposer = PDB.Superimposer()
    aligned_structures = [structures[0]]  # Include the reference structure in the list

    for i, structure in enumerate(structures[1:], start=1):
        target_atoms = [
            atom
            for atom in structure.get_atoms()
            if f"{atom.get_parent().get_id()[1]}-{atom.name}" in common_atoms
        ]

        super_imposer.set_atoms(ref_atoms, target_atoms)
        super_imposer.apply(structure.get_atoms())

        aligned_structure = f"aligned_structure_{i}.pdb"
        io = PDB.PDBIO()
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

        if struct_file.endswith('.pdb'):
            parser = PDB.PDBParser(QUIET=True)
            suffix = ".pdb"
        elif struct_file.endswith('.cif'):
            parser = PDB.MMCIFParser(QUIET=True)
            suffix = ".cif"
        else:
            raise NotImplementedError("Reporting only supported for .pdb and .cif filetypes")
        structure = parser.get_structure("", struct_file)

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
            output_file = f"{struct_file.replace(suffix, '')}_plddt.tsv"
            with open(output_file, "w") as outfile:
                outfile.write(" ".join(map(str, plddt_values)) + "\n")
            output_lddt.append(output_file)
        else:
            plddt_values_string = " ".join(map(str, plddt_values))
            output_lddt.append(plddt_values_string)

    return output_lddt, averages


print("Starting...")

version = "1.0.0"
model_name = {
    "esmfold": "ESMFold",
    "alphafold2": "AlphaFold2",
    "alphafold3": "Alphafold3",
    "colabfold": "ColabFold",
    "rosettafold_all_atom": "Rosettafold_All_Atom",
    "helixfold3": "HelixFold3",
    "boltz": "Boltz-1"
}

parser = argparse.ArgumentParser()
parser.add_argument("--type", dest="in_type")
parser.add_argument(
    "--generate_tsv", choices=["y", "n"], default="n", dest="generate_tsv"
)
parser.add_argument("--msa", dest="msa", default="NO_FILE")
parser.add_argument("--pdb", dest="pdb", required=True, nargs="+")
parser.add_argument("--name", dest="name")
parser.add_argument("--output_dir", dest="output_dir")
parser.add_argument("--html_template", dest="html_template")
parser.add_argument("--version", action="version", version=f"{version}")
parser.set_defaults(output_dir="")
parser.set_defaults(in_type="esmfold")
parser.set_defaults(name="")
args = parser.parse_args()

lddt_data, lddt_averages = pdb_to_lddt(args.pdb, args.generate_tsv)

generate_output_images(
    args.msa, lddt_data, args.name, args.output_dir, args.in_type, args.generate_tsv, args.pdb
)
# generate_plots(args.msa, args.plddt, args.name, args.output_dir)

print("generating html report...")
structures = args.pdb
structures.sort()
aligned_structures = align_structures(structures)

io = PDB.PDBIO()
ref_structure_path = "aligned_structure_0.pdb"
io.set_structure(aligned_structures[0])
io.save(ref_structure_path)
aligned_structures[0] = ref_structure_path

proteinfold_template = open(args.html_template, "r").read()
proteinfold_template = proteinfold_template.replace("*sample_name*", args.name)
proteinfold_template = proteinfold_template.replace(
    "*prog_name*", model_name[args.in_type.lower()]
)

args_pdb_array_js = ",\n".join([f'"{model}"' for model in structures])
proteinfold_template = re.sub(
    r"const MODELS = \[.*?\];",  # Match the existing MODELS array in HTML template
    f"const MODELS = [\n  {args_pdb_array_js}\n];",  # Replace with the new array
    proteinfold_template,
    flags=re.DOTALL,
)

averages_js_array = f"const LDDT_AVERAGES = {lddt_averages};"
proteinfold_template = proteinfold_template.replace(
    "const LDDT_AVERAGES = [];", averages_js_array
)

i = 0
for structure in aligned_structures:
    proteinfold_template = proteinfold_template.replace(
        f"*_data_ranked_{i}.pdb*", open(structure, "r").read().replace("\n", "\\n")
    )
    i += 1

if not args.msa.endswith("NO_FILE"):
    image_path = (
        f"{args.output_dir}/{args.msa}"
        if args.in_type.lower() == "colabfold"
        else f"{args.output_dir}/{args.name + ('_' if args.name else '')}seq_coverage.png"
    )
    with open(image_path, "rb") as in_file:
        proteinfold_template = proteinfold_template.replace(
            "seq_coverage.png",
            f"data:image/png;base64,{base64.b64encode(in_file.read()).decode('utf-8')}",
        )
else:
    pattern = r'<div id="seq_coverage_container".*?>.*?(<!--.*?-->.*?)*?</div>\s*</div>'
    proteinfold_template = re.sub(pattern, "", proteinfold_template, flags=re.DOTALL)

with open(
    f"{args.output_dir}/{args.name + ('_' if args.name else '')}coverage_LDDT.html",
    "r",
) as in_file:
    lddt_html = in_file.read()
    proteinfold_template = proteinfold_template.replace(
        '<div id="lddt_placeholder"></div>', lddt_html
    )

with open(
    f"{args.output_dir}/{args.name}_{args.in_type.lower()}_report.html", "w"
) as out_file:
    out_file.write(proteinfold_template)
