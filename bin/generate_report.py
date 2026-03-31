#!/usr/bin/env python3
from plot_utils import (
    reset_residue_numbers,
    sort_structures_by_rank,
    align_structures,
    plddt_from_struct_b_factor,
    generate_plddt_plot,
    generate_pae_plot,
    generate_sequence_coverage_plot,
)
from bs4 import BeautifulSoup
import json
import argparse
import os
from pathlib import Path

prog_name_mapping = {
    "proteinfold": "ProteinFold",
    "alphafold2": "AlphaFold2",
    "alphafold3": "AlphaFold3",
    "esmfold": "ESMFold",
    "colabfold": "ColabFold",
    "rosettafold-all-atom": "RoseTTAFold-All-Atom",
    "rosettafold2na": "RoseTTAFold2NA",
    "helixfold3": "HelixFold3",
    "boltz": "Boltz",
    "comparison": "Comparison",
}

def get_template_path():
    # Get directory where this script lives: modules/local/generate_report/
    script_dir = Path(__file__).parent.parent.parent  # Go up to modules/local/
    template_path = script_dir / "assets" / "report_template.html"
    
    if not template_path.exists():
        raise FileNotFoundError(
            f"Template not found: {template_path}\n"
            f"Expected: {script_dir}/assets/report_template.html"
        )
    
    return str(template_path)

def generate_report(name, out_dir, structures, num_structs_limit=5, msa_files=None, pae_files=None, prog="proteinfold", type="standard", html_template=None, write_htmls=True):

    PLOTLY_CONFIG = {"displayModeBar": True, "displaylogo": False, "scrollZoom": True}

    # Sort structures by name and limit to set number
    if len(structures) > num_structs_limit:
        print(f"Warning: More than {num_structs_limit} structures provided. Sorting and using only the first {num_structs_limit} structures.")
        sorted_structures = sort_structures_by_rank(structures, prog)
        structures = sorted_structures[:num_structs_limit]

    # Keep original file paths for reading structure data and NGL viewer
    structure_paths = list(structures)

    # Detect structure format for NGL viewer
    struct_format = "cif" if structure_paths[0].endswith(".cif") else "pdb"

    # Parse structures into BioPython objects with sequential residue numbering
    # (ESMFold, HF3 etc. restart numbering per chain — renumber to be sequential)
    parsed_structures = [reset_residue_numbers(s) for s in structure_paths]

    # For comparison mode, re-parse and align structures
    if type == "comparison":
        parsed_structures = align_structures(structure_paths)

    print("Structures:", structure_paths)

    # Parse HTML template with BeautifulSoup
    with open(html_template, "r") as f:
        soup = BeautifulSoup(f.read(), "html.parser")

    # Build configuration JSON for JavaScript
    config = {
        "reportType": type,
        "sampleName": name,
        "programName": prog_name_mapping.get(prog, prog),
        "structFormat": struct_format,
        "models": [f"Rank {idx+1}" for idx, _ in enumerate(parsed_structures)],
        "lddt_averages": [round(plddt_from_struct_b_factor(s).mean(), 2) for s in parsed_structures],
        "models_data": [open(s, "r").read().replace("\n", "\\n") for s in structure_paths],
    }

    # Inject configuration as JSON into a script tag
    config_script = soup.new_tag("script", type="application/json", attrs={"id": "report-config"})
    config_script.string = json.dumps(config)
    
    # Find or create head section and add config script
    head = soup.find("head")
    if head:
        head.append(config_script)
    else:
        # Fallback: add before first script tag
        first_script = soup.find("script")
        if first_script:
            first_script.insert_before(config_script)

    # Generate sequence coverage plot from first MSA file
    seq_cov_html = None
    if msa_files:
        seq_cov_fig = generate_sequence_coverage_plot(msa_files[0], out_dir, name)
        seq_cov_html = seq_cov_fig.to_html(
            full_html=False,
            include_plotlyjs="cdn",
            config=PLOTLY_CONFIG,
        )

    # Replace placeholder divs with content using BeautifulSoup
    seq_cov_placeholder = soup.find("div", attrs={"id": "seq_cov_placeholder"})
    if seq_cov_placeholder and seq_cov_html:
        seq_cov_placeholder.replace_with(BeautifulSoup(seq_cov_html, "html.parser"))

    # Generate the pLDDT plot and convert to HTML
    plddt_fig = generate_plddt_plot(parsed_structures)
    plddt_html = plddt_fig.to_html(
        full_html=False,
        include_plotlyjs="cdn",
        config=PLOTLY_CONFIG,
    )
    lddt_placeholder = soup.find("div", attrs={"id": "lddt_placeholder"})
    if lddt_placeholder:
        lddt_placeholder.replace_with(BeautifulSoup(plddt_html, "html.parser"))

    # Generate PAE plot from first PAE file (TODO: toggle PAE with model selection)
    if pae_files:
        pae_fig = generate_pae_plot(pae_files[0], out_dir, name)
        pae_html = pae_fig.to_html(
            full_html=False,
            include_plotlyjs="cdn",
            config=PLOTLY_CONFIG,
        )
        pae_placeholder = soup.find("div", attrs={"id": "pae_placeholder"})
        if pae_placeholder:
            pae_placeholder.replace_with(BeautifulSoup(pae_html, "html.parser"))

    if write_htmls:
        with open(f"{out_dir}/{name}_coverage_pLDDT.html", "w") as out_file:
            out_file.write(plddt_html)
        if seq_cov_html:
            with open(f"{out_dir}/{name}_coverage_MSA.html", "w") as out_file:
                out_file.write(seq_cov_html)

    # Write the final HTML report
    with open(f"{out_dir}/{name}_{type}_report.html", "w") as out_file:
        out_file.write(str(soup))

def main():
    parser = argparse.ArgumentParser(description="Generate protein structure reports.")
    parser.add_argument("--name", required=True, help="Name of the report.")
    parser.add_argument("--output_dir", required=True, help="Output directory for the report.")
    parser.add_argument("--structs", required=True, nargs="+", help="List of structure file paths (.pdb or .cif).")
    parser.add_argument("--msa", nargs="+", default=None, help="MSA file path(s).")
    parser.add_argument("--pae", nargs="+", default=None, help="PAE file path(s).")
    parser.add_argument("--prog", default="proteinfold", choices=["proteinfold", "alphafold2", "alphafold3", "esmfold", "colabfold", "rosettafold-all-atom", "rosettafold2na", "helixfold3", "boltz", "comparison"], type=str.lower, help="The program used to generate the structures.")
    parser.add_argument("--type", default="standard", choices=["standard", "comparison"], help="The type of report to generate.")
    parser.add_argument("--html_template", default=None, help="Path to the HTML report template.")
    parser.add_argument("--write_htmls", default=True, help="Write out separate files for each html plot.")

    args = parser.parse_args()

    print("Generating report.....")

    html_template = args.html_template or get_template_path()

    # Both these values could be missing - ESMFold for MSA, many others for PAE
    if args.msa and os.path.basename(args.msa[0]) == "NO_FILE":
        args.msa = None
    if args.pae and os.path.basename(args.pae[0]) == "NO_FILE":
        args.pae = None

    generate_report(
        name=args.name,
        out_dir=args.output_dir,
        structures=args.structs,
        num_structs_limit=5,
        msa_files=args.msa,
        pae_files=args.pae,
        prog=args.prog,
        type=args.type,
        html_template=html_template,
        write_htmls=args.write_htmls,
    )

if __name__ == "__main__":
    main()
