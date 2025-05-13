#!/usr/bin/env python

import os
import argparse
from collections import OrderedDict
import base64
import plotly.graph_objects as go
from Bio import PDB

def reset_residue_numbers(input_pdb, output_pdb):
    """
    Resets residue numbers (column 23-26) in a PDB file so the position starts from 1 for each chain
    and increment only when encountering a new residue.
    """
    with open(input_pdb, 'r') as infile, open(output_pdb, 'w') as outfile:
        current_residue_number = 1
        previous_residue_id = None
        previous_chain = None

        for line in infile:
            if line.startswith("ATOM") or line.startswith("HETATM"):
                chain = line[21]  # Extract the chain identifier (column 22)
                residue_id = line[22:26].strip()  # Extract the residue ID (column 23-26)

                # Reset residue numbering if the chain changes
                if chain != previous_chain:
                    current_residue_number = 1
                    previous_chain = chain
                    previous_residue_id = None

                # Increment residue number if it's a new residue
                if residue_id != previous_residue_id:
                    if previous_residue_id is not None:  # Only increment after the first residue
                        current_residue_number += 1
                    previous_residue_id = residue_id

                # Update the line with the new residue number
                updated_line = (
                    line[:22] +
                    f"{current_residue_number:4}" +
                    line[26:]
                )
                outfile.write(updated_line)

            else:
                # Write non-ATOM/HETATM lines (e.g., TER, PARENT) without changes
                outfile.write(line)

def generate_output(plddt_data, name, out_dir, generate_tsv, pdb):
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


def align_structures_old(structures):
    parser = PDB.PDBParser(QUIET=True)
    structures = [
        parser.get_structure(f"Structure_{i}", pdb) for i, pdb in enumerate(structures)
    ]

    ref_structure = structures[0]
    ref_atoms = [atom for atom in ref_structure.get_atoms()]

    super_imposer = PDB.Superimposer()
    aligned_structures = [structures[0]]  # Include the reference structure in the list

    for i, structure in enumerate(structures[1:], start=1):
        target_atoms = [atom for atom in structure.get_atoms()]

        super_imposer.set_atoms(ref_atoms, target_atoms)
        super_imposer.apply(structure.get_atoms())

        aligned_structure = f"aligned_structure_{i}.pdb"
        io = PDB.PDBIO()
        io.set_structure(structure)
        io.save(aligned_structure)
        aligned_structures.append(aligned_structure)

    return aligned_structures


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
    output_lddt = []
    averages = []

    for struct_file in struct_files:
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

            plddt_values.append(res_pLDDT_tot/res_atom_count) #residue-level mean for ESMfold atom-level pLDDT

        # Calculate the average PLDDT value for the current file
        if plddt_values:
            avg_plddt = sum(plddt_values) / len(plddt_values)
            averages.append(round(avg_plddt, 3))
        else:
            averages.append(0.0)

        if generate_tsv == "y":
            output_file = f"{pdb_file.replace('.pdb', '')}_plddt.tsv"
            with open(output_file, "w") as outfile:
                outfile.write(" ".join(map(str, plddt_values)) + "\n")
            output_lddt.append(output_file)
        else:
            plddt_values_string = " ".join(map(str, plddt_values))
            output_lddt.append(plddt_values_string)

    return output_lddt, averages


print("Starting...")

version = "1.0.0"
parser = argparse.ArgumentParser()
parser.add_argument("--type", dest="in_type")
parser.add_argument(
    "--generate_tsv", choices=["y", "n"], default="n", dest="generate_tsv"
)
parser.add_argument("--msa", dest="msa", required=True, nargs="+")
parser.add_argument("--pdb", dest="pdb", required=True, nargs="+")
parser.add_argument("--name", dest="name")
parser.add_argument("--output_dir", dest="output_dir")
parser.add_argument("--html_template", dest="html_template")
parser.add_argument("--version", action="version", version=f"{version}")
parser.set_defaults(output_dir="")
parser.set_defaults(in_type="comparison")
parser.set_defaults(name="")
args = parser.parse_args()

lddt_data, lddt_averages = pdb_to_lddt(args.pdb, args.generate_tsv)

generate_output(lddt_data, args.name, args.output_dir, args.generate_tsv, args.pdb)

print("generating html report...")

# Preprocess "esmfold" PDB files, to reset residues on additional chains
processed_pdbs = [
    (pdb_file.replace(".pdb", "_align_residues.pdb") if "esmfold" in pdb_file else pdb_file)
    for pdb_file in args.pdb
]

for pdb_file, output_pdb in zip(args.pdb, processed_pdbs):
    if "esmfold" in pdb_file:
        reset_residue_numbers(pdb_file, output_pdb)

structures = processed_pdbs  # Use the final processed list
aligned_structures = align_structures(structures)

io = PDB.PDBIO()
ref_structure_path = "aligned_structure_0.pdb"
io.set_structure(aligned_structures[0])
io.save(ref_structure_path)
aligned_structures[0] = ref_structure_path

alphafold_template = open(args.html_template, "r").read()
alphafold_template = alphafold_template.replace("*sample_name*", args.name)
alphafold_template = alphafold_template.replace("*prog_name*", args.in_type)

args_pdb_array_js = (
    "const MODELS = [" + ",\n".join([f'"{model}"' for model in structures]) + "];"
)
alphafold_template = alphafold_template.replace("const MODELS = [];", args_pdb_array_js)

seq_cov_imgs = []
seq_cov_methods = []
for msa, pdb in zip(args.msa, args.pdb):
    if msa != "NO_FILE":
        image_path = msa
        method = pdb.split(".pdb")[0]
        seq_cov_methods.append(method)
        with open(image_path, "rb") as in_file:
            encoded_image = base64.b64encode(in_file.read()).decode("utf-8")
            seq_cov_imgs.append(f"data:image/png;base64,{encoded_image}")

#MSA IMAGES
args_msa_array_js = (
    f"""const SEQ_COV_IMGS = [{", ".join([f'"{img}"' for img in seq_cov_imgs])}];"""
)
alphafold_template = alphafold_template.replace(
    "const SEQ_COV_IMGS = [];", args_msa_array_js
)
#MSA IMAGE LABELS
args_msa_method_array_js = (
    f"""const SEQ_COV_METHODS = [{", ".join([f'"{method}"' for method in seq_cov_methods])}];"""
)
alphafold_template = alphafold_template.replace(
    "const SEQ_COV_METHODS = [];", args_msa_method_array_js
)

averages_js_array = f"const LDDT_AVERAGES = {lddt_averages};"
alphafold_template = alphafold_template.replace(
    "const LDDT_AVERAGES = [];", averages_js_array
)

i = 0
for structure in aligned_structures:
    alphafold_template = alphafold_template.replace(
        f"*_data_ranked_{i}.pdb*", open(structure, "r").read().replace("\n", "\\n")
    )
    i += 1

with open(
    f"{args.output_dir}/{args.name + ('_' if args.name else '')}coverage_LDDT.html",
    "r",
) as in_file:
    lddt_html = in_file.read()
    alphafold_template = alphafold_template.replace(
        '<div id="lddt_placeholder"></div>', lddt_html
    )

with open(
    f"{args.output_dir}/{args.name}_{args.in_type.lower()}_report.html", "w"
) as out_file:
    out_file.write(alphafold_template)
