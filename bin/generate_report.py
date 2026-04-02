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
import os
import re
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

def _tool_program_label(structure_path):
    basename = Path(structure_path).stem.lower()
    for key, label in prog_name_mapping.items():
        if key not in ("comparison", "proteinfold") and key in basename:
            return label
    # If no specific tool is detected, return the base filename as a fallback (without extension)
    return Path(structure_path).stem

def generate_report(name, out_dir, structures, num_structs_limit=5, msa_files, pae_files, prog, report_type, html_template):

    PLOTLY_CONFIG = {"displayModeBar": True, "displaylogo": False, "scrollZoom": True}

    # Sort structures by name and limit to set number
    # For comparison report using single top ranked structure from each tool so sorting not performed - structures should be pre-sorted and limited by user input
    if report_type != "comparison" and len(structures) > num_structs_limit:
        print(f"Warning: More than {num_structs_limit} structures provided. Sorting and using only the first {num_structs_limit} structures.")
        sorted_structures = sort_structures_by_rank(structures, prog)
        structures = sorted_structures[:num_structs_limit]

    # Keep original file paths for reading structure data and NGL viewer
    structure_paths = list(structures)

    # Use PDB format for NGL viewer convenience. Since I'm parsing BioPython obejcts I can force format from object regardless of input file type
    struct_format = "pdb"

    # Parse structures into BioPython objects with sequential residue numbering
    # (ESMFold, HF3 etc. restart numbering per chain — renumber to be sequential)
    parsed_structures = [reset_residue_numbers(s) for s in structure_paths]

    # For comparison mode, re-parse and align structures
    if report_type == "comparison":
        parsed_structures = align_structures(structure_paths)

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
        "report_type": report_type,
        "sampleName": name,
        "programName": prog_name_mapping.get(prog, prog),
        "structFormat": struct_format,
        "models": model_labels,
        "plddt_averages": [round(plddt_from_struct_b_factor(s).mean(), 2) for s in parsed_structures],
        "models_data": [structure_to_pdb_string(s) for s in parsed_structures],
    }

    # Inject configuration as a JSON script tag before </head>
    config_script = f'<script report_type="application/json" id="report-config">{json.dumps(config)}</script>'
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
    )
    html = html.replace('<div id="plddt_placeholder"></div>', plddt_html, 1)

    # Generate PAE plot from first PAE file (TODO: toggle PAE with model selection), Not used in comparison report
    if pae_files:
        pae_fig = generate_pae_plot(pae_files[0])
        pae_html = pae_fig.to_html(
            full_html=False,
            include_plotlyjs="cdn",
            config=PLOTLY_CONFIG,
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
    parser.add_argument("--prog", default="proteinfold", choices=["proteinfold", "alphafold2", "alphafold3", "esmfold", "colabfold", "rosettafold-all-atom", "rosettafold2na", "helixfold3", "boltz", "comparison"], report_type=str.lower, help="The program used to generate the structures.")
    parser.add_argument("--report_type", default="standard", choices=["standard", "comparison"], help="The report_type of report to generate.")
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

if __name__ == "__main__":
    main()
