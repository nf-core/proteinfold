import plotly.graph_objects as go
from Bio import PDB
from io import StringIO
import numpy as np
import os

def structure_to_pdb_string(structure):
    """Serialize a BioPython Structure object to a PDB-format string in memory.
    Useful util to work with object directly and not have to write intermediate to disk
    """
    io = PDB.PDBIO()
    io.set_structure(structure)
    string_io = StringIO()
    io.save(string_io)
    return string_io.getvalue()


def reset_residue_numbers(structure):
    """
    Resets residue numbering in a PDB file, because ESMFold starts renumbering
    at 1 for each chain and increments only when encountering a new residue.
    """
    if str(structure).endswith(".pdb"):
        parser = PDB.PDBParser(QUIET=True)
    elif str(structure).endswith(".cif"):
        parser = PDB.MMCIFParser(QUIET=True)
    else:
        raise ValueError(f"{structure} is neither a PDB or mmCIF file!")

    struct_obj = parser.get_structure("structure", structure)

    for model in struct_obj:
        for chain in model:
            for idx, residue in enumerate(chain.get_residues(), start=1):
                # Do a swap in place to renumber the residue, the other entries in the tuple can stay the same
                # See: https://biopython.org/docs/1.76/api/Bio.PDB.Chain.html#Bio.PDB.Chain.Chain.__getitem__
                het_atom, _, insertion_code = residue.get_id()
                residue.id = (het_atom, idx, insertion_code)

    return struct_obj

# TODO: Barcelona team to implement AF3
def sort_structures_by_rank(structures, prog):
    """
    Sorts a list of structures based on their rank. Handles different program naming conventions.

    Returns:
        List of structure files sorted by rank (always returns list, even for single structures)
    """
    if prog == "alphafold2":
        # AlphaFold2 structures are named with [run]/ranked_[rank].pdb
        sorted_structures = sorted(structures, key=lambda x: int(os.path.basename(x).replace('ranked_', '').split('.')[0]))
    elif prog == "colabfold":
        # ColabFold structures are named with [run]_unrelaxed_rank_[rank]_alphafold2_ptm_model_[num]_seed_[seed].pdb
        sorted_structures = sorted(structures, key=lambda x: int(os.path.basename(x).split('_')[3]))
    elif prog == "helixfold3":
        # HelixFold3 structures are named with .../[run]/[run]-rank[rank]/predicted_structure.pdb
        sorted_structures = sorted(structures, key=lambda x: int(os.path.dirname(x).split('rank')[-1]))
    elif prog == "boltz":
        # Boltz structures are named with ..._model_[diffusion_samples-1].[pdb|cif]
        sorted_structures = sorted(structures, key=lambda x: int(os.path.basename(x).split('_model_')[-1].split('.')[0]))
    elif prog == "esmfold" or prog == "rosettafold-all-atom":
        # ESMFold and RoseTTAFold only produce one structure
        sorted_structures = structures if isinstance(structures, list) else [structures]
    else:
        print(f"Warning: Sorting not implemented for {prog}. Using original order.")
        sorted_structures = structures if isinstance(structures, list) else [structures]

    return sorted_structures if isinstance(sorted_structures, list) else [sorted_structures]

def align_structures(structures):
    """
    Align multiple structures against the first (reference) structure.
    Uses common atoms for superimposition (handles cases where structures aren't complete).

    Returns:
        List of BioPython structure objects aligned to the first structure
    """
    if not structures:
        raise ValueError("No structures provided for alignment.")

    if structures[0].endswith(".pdb"):
        parser = PDB.PDBParser(QUIET=True)
    elif structures[0].endswith(".cif"):
        parser = PDB.MMCIFParser(QUIET=True)
    else:
        raise ValueError(f"{structures[0]} is neither a PDB or mmCIF file!")

    parsed_structures = [parser.get_structure(f"structure-{idx}", structure) for idx, structure in enumerate(structures)]
    ref_structure = parsed_structures[0]

    def get_atom_ids(structure):
        # Note: this is a *set* of atom_ids due to the {} surrounding the comprehension
        return {(atom.get_parent().get_parent().get_id(), atom.get_parent().get_id(), atom.name) for atom in structure.get_atoms() if atom.element != 'H'}

    # Find common atoms across all structures (progressive intersection)
    # This allows alignment even if structures are incomplete or have different atom coverage
    common_atoms = get_atom_ids(ref_structure)
    for structure in parsed_structures[1:]:
        common_atoms.intersection_update(get_atom_ids(structure))

    if not common_atoms:
        raise ValueError("No common atoms found between structures for alignment.")

    def extract_atoms(structure, atom_ids):
        # Must return a sorted list (not set) so ref/target atoms correspond positionally
        atoms = [atom for atom in structure.get_atoms() if (atom.get_parent().get_id(), atom.name) in atom_ids]
        return sorted(atoms, key=lambda a: (a.get_parent().get_id(), a.name))

    ref_atoms = extract_atoms(ref_structure, common_atoms)

    # The aligned structures will be the parsed structures aligned to the common atoms of the reference structure
    super_imposer = PDB.Superimposer()
    aligned_structures = [ref_structure]  # Reference needs no alignment
    for idx, structure in enumerate(parsed_structures[1:], start=1):
        target_atoms = extract_atoms(structure, common_atoms)
        super_imposer.set_atoms(list(ref_atoms), list(target_atoms))
        super_imposer.apply(structure.get_atoms())
        aligned_structures.append(structure)

    return aligned_structures

def plddt_from_struct_b_factor(structure):
    """
    Extracts residue pLDDT values from the b-factor column using BioPython.
    Accepts either a file path (str/Path) or a pre-parsed BioPython Structure object.
    """
    if isinstance(structure, (str, os.PathLike)):
        if str(structure).endswith(".pdb"):
            parser = PDB.PDBParser(QUIET=True)
        elif str(structure).endswith(".cif"):
            parser = PDB.MMCIFParser(QUIET=True)
        else:
            raise ValueError(f"{structure} is neither a PDB or mmCIF file!")
        struct_obj = parser.get_structure(os.path.basename(str(structure)), str(structure))
    else:
        # Already a BioPython structure object
        struct_obj = structure

    res_plddts = []

    for model in struct_obj:
        for chain in model:
            for residue in chain:
                atom_list = residue.get_unpacked_list()
                atom_plddt_tot = 0
                # Handle both atom-wise and residue-wise pLDDT values
                for atom in residue:
                    atom_plddt = atom.get_bfactor()
                    atom_plddt_tot += atom_plddt

                res_plddt = float(atom_plddt_tot / len(atom_list)) if atom_list else 0.0

                # Ensure values are in [0, 100] range
                if res_plddt < 1:
                    res_plddt *= 100

                res_plddts.append(res_plddt)

    res_plddts = np.array(res_plddts)
    res_plddts = np.round(res_plddts, 2)

    return res_plddts

def generate_plddt_plot(structures):
    """
    Generate a Plotly figure for pLDDT per position for given structures.

    Args:
        structures (list): List of structure file paths or BioPython structure objects.

    Returns:
        go.Figure: Plotly figure object with pLDDT data.
    """
    plddt_per_struct = {}

    for idx, struct in enumerate(structures):
        plddt_per_struct[f"rank-{idx}"] = plddt_from_struct_b_factor(struct)

    fig = go.Figure()

    for idx, (name, plddts) in enumerate(plddt_per_struct.items()):
        fig.add_trace(
            go.Scatter(
                x=list(range(len(plddts))),
                y=plddts,
                mode="lines",
                name=name,
                text=[f"({pos}, {value:.2f})" for pos, value in enumerate(plddts)],
                hoverinfo="text",
            )
        )
    fig.update_layout(
        xaxis=dict(
            title="Residue position", showline=True, linecolor="black", gridcolor="WhiteSmoke"
        ),
        yaxis=dict(
            title="pLDDT",
            range=[0, 100],
            showline=True,
            linecolor="black",
            gridcolor="WhiteSmoke",
        ),
        legend=dict(
            yanchor="bottom", y=0.02, xanchor="right", x=1, bordercolor="Black", borderwidth=1
        ),
        plot_bgcolor="white",
        autosize=True,
    )

    return fig

def process_msas(msa_path):
    msa = np.loadtxt(msa_path, dtype=int)

    query_sequence = msa[0]
    seqid_match = np.mean(msa == query_sequence, axis=1)

    # Sort sequences by sequence identity
    seqid_sort_indices = np.argsort(seqid_match)
    sorted_msa = msa[seqid_sort_indices]
    sorted_seqid = seqid_match[seqid_sort_indices]

    non_gaps_msas = np.where(sorted_msa != 21, 1.0, np.nan)

    # Scale non-gap positions by sequence identity
    final_msas = non_gaps_msas * sorted_seqid[:, None]

    return final_msas, non_gaps_msas

def generate_sequence_coverage_plot(msa_path, out_dir, name, save_image=False):
    """
    Generate an interactive Plotly heatmap for sequence coverage with depth overlay.
    """
    # Pastel rainbow_r: matplotlib rainbow_r colours blended ~60% with white
    PASTEL_RAINBOW_R = [
        [0.00, "#CC99FF"],  # pale violet  (low identity)
        [0.17, "#9999FF"],  # pale blue
        [0.33, "#99FFFF"],  # pale cyan
        [0.50, "#99FF99"],  # pale green
        [0.67, "#FFFF99"],  # pale yellow
        [0.83, "#FFCC99"],  # pale orange
        [1.00, "#FF9999"],  # pale red     (high identity)
    ]

    final_msas, non_gaps_msas = process_msas(msa_path)
    n_seqs = final_msas.shape[0]
    seq_depth_counts = np.sum(~np.isnan(non_gaps_msas), axis=0)

    fig = go.Figure()

    # Heatmap — sequence identity, NaN gaps rendered as white
    fig.add_trace(
        go.Heatmap(
            z=final_msas,
            colorscale=PASTEL_RAINBOW_R,
            zmin=0,
            zmax=1,
            colorbar=dict(
                title=dict(text="Sequence<br>identity", side="right"),
                thickness=15,
                len=0.75,
            ),
            name="",
        )
    )

    # Coverage depth line — same y-axis as heatmap (both in units of sequences)
    fig.add_trace(
        go.Scatter(
            x=list(range(len(seq_depth_counts))),
            y=seq_depth_counts,
            mode="lines",
            line=dict(color="black", width=1.5),
            name="Coverage depth",
        )
    )

    fig.update_layout(
        xaxis=dict(
            title="Residue position",
            showline=True,
            linecolor="black",
            gridcolor="WhiteSmoke",
            fixedrange=True,
        ),
        yaxis=dict(
            title="Sequences",
            range=[0, n_seqs],
            showline=True,
            linecolor="black",
            gridcolor="WhiteSmoke",
            fixedrange=True,
        ),
        plot_bgcolor="white",
        legend=dict(yanchor="bottom", y=0.02, xanchor="right", x=0.98),
        autosize=True,
    )

    if save_image:
        image_path = f"{out_dir}/{name+('_' if name else '')}seq_coverage.png"
        fig.write_image(image_path, width=800, height=600)
        return fig, image_path
    else:
        return fig

def generate_pae_plot(pae_path, out_dir, name, save_image=False):
    """
    Generate an interactive Plotly heatmap for Predicted Aligned Error (PAE) data.
    """
    pae = np.genfromtxt(pae_path, delimiter="\t")
    max_pae = 31.75 # Capped from AlphaFold's value 
    fig = go.Figure()

    # Add heatmap with green colorscale
    fig.add_trace(
        go.Heatmap(
            z=pae,
            colorscale="Greens_r",
            zmin=0,
            zmax=max_pae,
            colorbar={"title": "PAE (Å)"},
        )
    )

    fig.update_layout(
        title=dict(text="Predicted Aligned Error", x=0.5, xanchor="center"),
        xaxis=dict(title="Scored Residue"),
        yaxis=dict(title="Aligned Residue"),
        autosize=True,
    )

    if save_image:
        image_path = f"{out_dir}/{name+('_' if name else '')}pae.png"
        fig.write_image(image_path, width=800, height=800)
        return fig, image_path
    else:
        return fig
