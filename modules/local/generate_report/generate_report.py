from plot_utils import (
    reset_residue_numbers,
    sort_structures_by_rank,
    align_structures,
    plddt_from_struct_b_factor,
    generate_plddt_plot,
    generate_pae_plot,
    generate_sequence_coverage_plot,
)
import base64
import argparse

# TODO: Barcelona team to implement AF3, others
prog_name_mapping = {
    "proteinfold": "ProteinFold",
    "alphafold2": "AlphaFold2",
    "esmfold": "ESMFold",
    "colabfold": "ColabFold",
    "rosettafold-all-atom": "RoseTTAFold-All-Atom",
    "helixfold3": "HelixFold3",
    "boltz1": "Boltz1",
}

def generate_report(name, out_dir, structures, num_structs_limit=5, msa_files=None, pae_files=None, prog="ProteinFold", type="standard", html_template=None, write_htmls=True, seq_cov_as_html=False):

    # Change this to not just be ESMFold. HF3 resets on chainbreaks. Have structure res sequential just in case
    for structure in structures:
        structure = reset_residue_numbers(structure)

    # Sort structures by name and limit to set set number
    if len(structures) > num_structs_limit:
        print(f"Warning: More than {num_structs_limit} structures provided. Sorting and using only the first {num_structs_limit} structures.")
        sorted_structures = sort_structures_by_rank(structures, prog)
        structures = sorted_structures[:num_structs_limit]

    # Replace structures with aligned versions
    if type == "comparison":
        aligned_structures = align_structures(structures, save_ref_structure=True)
        structures = aligned_structures

    # Keeping for parsing visibility purposes
    print("Structures:", structures)

    #TODO: should really use a proper HTML parser for this, like BeautifulSoup or html5lib. strings prone to failure
    #However, most replacements are simple and this is faster
    template = open(html_template, "r").read()
    template = template.replace("*sample_name*", name)
    template = template.replace("*prog_name*", prog_name_mapping[prog])

    lddt_averages = []
    for structure in structures:
        lddt_averages.append(round(plddt_from_struct_b_factor(structure).mean(), 2))
    averages_js_array = f"const LDDT_AVERAGES = {lddt_averages};"
    template = template.replace("const LDDT_AVERAGES = [];", averages_js_array)

    # Populate MODELS into the HTML templat
    rank_names = [f"Rank {idx+1}" for idx, _ in enumerate(structures)]
    model_names_js = ("const MODELS = [" + ",\n".join([f'"{model}"' for model in rank_names]) + "];")
    template = template.replace("const MODELS = [];", model_names_js)

    # Populate MODELS_DATA with the content of the PDB files
    # TODO: If the .cif string is written as a literal in the report, will it still render? Probably, not be see the logic
    pdb_strings = [open(structure, "r").read().replace("\n", "\\n") for structure in structures]
    models_data = ",\n".join([f'"{pdb_string}"' for pdb_string in pdb_strings])
    models_data_js = f"const MODELS_DATA = [{models_data}];"
    template = template.replace("const MODELS_DATA = [];", models_data_js)

    # Generate sequence coverage plots and convert to HTML
    if msa_files:
        for msa_file in msa_files:
            seq_cov_fig, seq_cov_img_path = generate_sequence_coverage_plot(msa_file, out_dir, name, save_image=True)
            seq_cov_img_encoded = base64.b64encode(open(seq_cov_img_path, "rb").read()).decode("utf-8")
            seq_cov_img_tag = f'<img src="data:image/png;base64,{seq_cov_img_encoded}" alt="Sequence Coverage Image">'

            seq_cov_html = seq_cov_fig.to_html(
                full_html=False,
                include_plotlyjs="cdn",
                config={"displayModeBar": True, "displaylogo": False, "scrollZoom": True},
            )
    if seq_cov_as_html == True:
        template = template.replace('<div id="seq_cov_placeholder"></div>', seq_cov_html)
    else:
        template = template.replace('<div id="seq_cov_placeholder"></div>', seq_cov_img_tag)

    # Generate the pLDDT plot and convert to HTML
    plddt_fig = generate_plddt_plot(structures)
    plddt_html = plddt_fig.to_html(
        full_html=False,
        include_plotlyjs="cdn",
        config={"displayModeBar": True, "displaylogo": False, "scrollZoom": True},
    )
    template = template.replace('<div id="lddt_placeholder"></div>', plddt_html)

   #Generate PAE plot and conver to HTML TODO: currently onlt the first
    if pae_files:
        pae_figs = []
        for pae_file in pae_files:
            # TODO: ensure PAE files are sorted and limited to num_structs_limit
            pae_figs.append(generate_pae_plot(pae_file, out_dir, name, save_image=True))
        pae_html = pae_figs[0].to_html(
            full_html=False,
            include_plotlyjs="cdn",
            config={"displayModeBar": True, "displaylogo": False, "scrollZoom": True},
        )
        template = template.replace('<div id="pae_placeholder"></div>', pae_html)
    # TODO: need logic to keep PAEs in sync with structure upon click
    # TODO: look at the Sequence coverage approach (e.g. ESMFold has none)
    else:
        pass
        # TODO: Remove the PAE div if no PAE files are provided.
        # The below approach will remove the div but needs dynamic resizing in the report
        # pae_section_text = """
        # <div id="pae-title" class="text-4xl font-bold tracking-tight mb-6">PAE</div>
        # <div class="p-6 bg-white shadow-md rounded">
        #   <div id="pae_container" class="w-[660px] min-h-[600px] flex justify-center items-center mx-auto">
            # <div id="pae_placeholder"></div>
        #   </div>
        # </div>
        # """
        # template = template.replace(pae_section_text.strip(), "")

    if write_htmls:
        with open(f"{out_dir}/{name}_coverage_pLDDT.html", "w") as out_file:
            out_file.write(plddt_html)
        with open(f"{out_dir}/{name}_coverage_MSA.html", "w") as out_file:
            out_file.write(seq_cov_html)

    # Write the final HTML report
    with open(f"{out_dir}/{name}_{type}_report.html", "w") as out_file:
        out_file.write(template)

def main():
    parser = argparse.ArgumentParser(description="Generate protein structure reports.")
    parser.add_argument("--name", required=True, help="Name of the report.")
    parser.add_argument("--output_dir", required=True, help="Output directory for the report.")
    parser.add_argument("--structs", required=True, nargs="+", help="List of structure file paths.")
    parser.add_argument("--msa", nargs="+", default=None, help="MSA file path.")
    parser.add_argument("--paes", nargs="+", default=None, help="List of PAE file paths (optional).")
    parser.add_argument("--prog", default="proteinfold", choices=["alphafold2", "esmfold", "colabfold", "rosettafold-all-atom", "helixfold3", "boltz1"], type=str.lower, help="The program used to generate the structures, can be called in the workflow")
    parser.add_argument("--type", default="standard", choices=["standard", "comparison"], help="The type of report file generated .") # TODO: change to --type with options in case there are other reports
    #TODO: remove --html_template as this is already determined by the type
    parser.add_argument("--html_template", default=None, help="Path to the HTML template for comparison (optional).")
    parser.add_argument("--write_htmls", default=True, help="Write out seperate files for each html plot (optional).")

    args = parser.parse_args()

    print("Generating report.....")

    # TODO: want a better way of pathing this
    if args.type == "comparison":
        html_template = "../.../assets/comparison_template.html"
    elif args.type == "standard":
        html_template = "../../assets/report_template.html"
    else:
        html_template = args.html_template


    # Both these values could be missing - EMSFold for MSA, many others for PAE
    if os.path.basename(args.msa) == "NO_FILE":
        args.peas=None
    if os.path.basename(args.paes) == "NO_FILE":
        args.peas=None

    generate_report(
        name=args.name,
        out_dir=args.output_dir,
        structures=args.structs,
        num_structs_limit=5,
        msa_files=args.msa,
        pae_files=args.paes,
        prog=args.prog,
        type=args.type,
        html_template=html_template,
        write_htmls=args.write_htmls,
        seq_cov_as_html=False,
    )

if __name__ == "__main__":
    main()
