from collections import OrderedDict
import plotly.graph_objects as go
from Bio import PDB
import matplotlib.pyplot as plt
import numpy as np
import os

def reset_residue_numbers(structure):
    """
    Resets residue numbering in a PDB file, because ESMFold starts
    and increment only when encountering a new residue.
    """
    if str(structure).endswith(".pdb"):
        parser = PDB.PDBParser(QUIET=True)
    elif str(structure).endswith(".cif"):
        parser = PDB.MMCIFParser(QUIET=True)
    else:
        print(f"{structure} is neither a PDB or mmCIF file!")
        return

    structure = parser.get_structure("structure", structure)

    for model in structure:
        for idx, residue in enumerate(model.get_residues(), start=1):
        # Do a swap in place to renumber the residue, the other entries in the tuple can stay the same
        # See: https://biopython.org/docs/1.76/api/Bio.PDB.Chain.html#Bio.PDB.Chain.Chain.__getitem__
        het_atom, _, insertion_code = residue.get_id()
        residue.id = (het_atom, idx, insertion_code)

    io = PDB.PDBIO()
    io.set_structure(structure)

    return structure

# TODO: Barcelona team to implement AF3
def sort_structures_by_rank(structures, prog):
    """
    Sorts a list of structures based on their rank. Needs to handle different program naming
    """
    if prog == "alphafold2":
        # AlphaFold2 structures are named with [run]/ranked_[rank].pdb
        sorted_structures = sorted(structures, key=lambda x: int(os.path.basename(x).replace('ranked_', '').split('.')[0]))
    if prog == "colabfold":
        # ColabFold structures are named with [run]_unrelaxed_rank_[rank]_alphafold2_ptm_model_[num]_seed_[seed].pdb
        sorted_structures = sorted(structures, key=lambda x: int(os.path.basename(x).split('_')[3]))
    if prog == "helixfold3":
        # HelixFold3 structures are named with .../[run]/[run]-rank[rank]/predicted_structure.pdb
        sorted_structures = sorted(structures, key=lambda x: int(os.path.dirname(x).split('rank')[-1]))
    if prog == "esmfold" or "rosettafold-all-atom":
        # ESMFold and RoseTTAFold only produce one structure
        sorted_structures = structures[0]
    if prog == "boltz1":
        # Boltz1 structures are named with ..._model_[diffusion_samples-1].[pdb|cif]
        sorted_structures = sorted(structures, key=lambda x: int(os.path.basename(x).split('_model_')[-1]))
    else:
        print(f"Warning: Sorting not implemented for {prog}. Using original order.")
        return structures

    return sorted_structures

def align_structures(structures):

    if not structures:
        raise ValueError("No structures provided for alignment.")

    if structures[0].endswith(".pdb"):
        parser = PDB.PDBParser(QUIET=True)
    elif structures[0].endswith(".cif"):
        parser = PDB.MMCIFParser(QUIET=True)
    else:
        raise ValueError(f"{structure} is neither a PDB or mmCIF file!")

    parsed_structures = [parser.get_structure(f"structure-{idx}", structure) for idx, structure in enumerate(structures)]
    ref_structure = parsed_structures[0]

    def get_atom_ids(structure):
        # Note: this is a *set* of atom_ids due to the {} surrounding the comprehension
        return {(atom.get_parent().get_id(), atom.name) for atom in structure.get_atoms()}

    # TODO: do we want to raise and error if the structures are not identical atomically, or keep the ability to sub-align?
    # Update the atoms shared between structures with progressive intersections
    common_atoms = get_atom_ids(ref_structure)
    for structure in parsed_structures[1:]:
        common_atoms.intersection_update(get_atom_ids(structure))

    if not common_atoms:
        raise ValueError("No common atoms found between structures.")

    def extract_atoms(structure, atom_ids):
        # Note: this comprehension returns an atom *object* for each atom in the structure
        return {atom for atom in structure.get_atoms() if (atom.get_parent().get_id(), atom.name) in atom_ids}

    ref_atoms = extract_atoms(ref_structure, common_atoms)

    # The aligned structures will be the parsed structures aligned to the common atoms of the reference structure
    super_imposer = PDB.Superimposer()
    aligned_structures = []
    for idx, structure in enumerate(parsed_structures):
        # The reference structure doesn't need to be aligned so can be skipped
        if idx == 0:
            aligned_structures.append(structure)
            continue

        target_atoms = extract_atoms(structure, common_atoms)
        super_imposer.set_atoms(ref_atoms, target_atoms)
        super_imposer.apply(structure.get_atoms())

        io = PDB.PDBIO()
        io.set_structure(structure)
        aligned_structures.append(structure)

    # Technically, parsed_structures now also points to the same aligned structures, but I've kept for readability
    return aligned_structures

def plddt_from_struct_b_factor(structure):
    """
    Uses the BioPython PDB package to extract residue pLDDT values from the b-factor column. Iterates over PDB objects rather than processes raw file
    """
    if str(structure).endswith(".pdb"):
        parser = PDB.PDBParser(QUIET=True)
        structure = parser.get_structure(id=id, file=structure)
    elif str(structure).endswith(".cif"):
        parser = PDB.MMCIFParser(QUIET=True)
        structure = parser.get_structure(structure_id=id, filename=structure)
    else:
        print(f"{structure} is neither a PDB or mmCIF file!")

    res_list = []
    res_plddts = []
    plddt_tot = 0

    for model in structure:
        for chain in model:
            chain_res_list = chain.get_unpacked_list()
            res_list.extend(chain_res_list)
            for residue in chain:
                atom_list = residue.get_unpacked_list()
                atom_plddt_tot = 0
                for atom in residue:  # ESMFold and others have separate atom-wise values, so doing atom-wise to cover that and residue-wise
                    atom_plddt = atom.get_bfactor()
                    atom_plddt_tot += atom_plddt

                res_plddt = float(atom_plddt_tot / len(atom_list))

                if (res_plddt < 1):  # RFAA the multiplication of mean isn't failing. Anyway covering to a [0,100] range for any structure file1
                    res_plddt *= 100

                res_plddts.append(res_plddt)
                plddt_tot += res_plddt

    res_plddts = np.array(res_plddts)
    res_plddts = np.round(res_plddts, 2)

    return res_plddts

def generate_plddt_plot(structures):
    """
    Generate a Plotly figure for predicted LDDT per position for given structures.

    Args:
        structures (list): List of structure file paths.

    Returns:
        go.Figure: Plotly figure object with pLDDT data.
    """
    plddt_per_struct = OrderedDict()

    for struct in structures:
        plddt_per_struct[struct] = plddt_from_struct_b_factor(struct)

    fig = go.Figure()

    for idx, (struct, plddts) in enumerate(plddt_per_struct.items()):
        fig.add_trace(
            go.Scatter(
                x=list(range(len(plddts))),
                y=plddts,
                mode="lines",
                name=f"rank-{idx}",
                text=[f"({idx}, {value:.2f})" for idx, value in enumerate(plddts)],
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
            showline=True,
            linecolor="black",
            gridcolor="WhiteSmoke",
        ),
        legend=dict(
            yanchor="bottom", y=0.02, xanchor="right", x=1, bordercolor="Black", borderwidth=1
        ),
        plot_bgcolor="white",
        width=600,
        height=600,
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

def generate_sequence_coverage_plot(msa_path, out_dir, name, save_image=True):
    final_msas, non_gaps_msas = process_msas(msa_path)
    #
    seq_depth_counts = np.sum(~np.isnan(non_gaps_msas), axis=0)

    # TODO: don't have a seperate save image plot and an HTML plotly ploy
    # ##################################################################
    # Plot the sequence coverage with matplotlib and save as image
    # ##################################################################
    if save_image:
        image_path = f"{out_dir}/{name+('_' if name else '')}seq_coverage.png"
        plt.figure(figsize=(14, 14), dpi=100)
        plt.title("Sequence coverage", fontsize=30, pad=36)
        plt.imshow(
            final_msas,
            interpolation="nearest",
            aspect="auto",
            cmap="rainbow_r",
            vmin=0,
            vmax=1,
            origin="lower",
        )


        plt.plot(seq_depth_counts, color="black")
        plt.xlim(-0.5, len(final_msas[0]) - 0.5)
        plt.ylim(-0.5, len(final_msas) - 0.5)

        plt.tick_params(axis="both", which="both", labelsize=18)

        cbar = plt.colorbar()
        cbar.set_label("Sequence identity to query", fontsize=24, labelpad=24)
        cbar.ax.tick_params(labelsize=18)
        plt.xlabel("Positions", fontsize=24, labelpad=24)
        plt.ylabel("Sequences", fontsize=24, labelpad=36)
        plt.savefig(image_path)

        # ##################################################################
        # Interactive HTML plot of sequence coverage
        fig = go.Figure()
        fig.add_trace(
            go.Heatmap(
                z=final_msas,
                colorscale="Rainbow_r",
                zmin=0,
                zmax=1,
                colorbar={"title": 'Your title'}
            )
        )
        # Add black line for sequence coverage depth
        fig.add_trace(
            go.Scatter(
                x=list(range(len(seq_depth_counts))),
                y=seq_depth_counts,
                mode="lines",
                line=dict(color="black", width=2),
                name="Coverage Depth",
            )
        )
        fig.update_layout(
            title=dict(text="Sequence coverage", x=0.5, xanchor="center"),
            xaxis_title="Positions", yaxis_title="Sequences",
        )

    if save_image:
        return fig, image_path
    else:
        return fig

def generate_pae_plot(pae_path, out_dir, name, save_image=True):
    """
    Generate a Plotly heatmap for Predicted Aligned Error (PAE) data.

    Args:
        pae (2D array): The PAE matrix.
    Returns:
        fig: A Plotly figure object of the PAE heatmap in green color scale
    """
    pae = np.genfromtxt(pae_path, delimiter="\t")
    max_pae = np.max(pae)
    fig = go.Figure()

    # Add heatmap
    fig.add_trace(
        go.Heatmap(
            z=pae,
            colorscale="Greens_r",
            zmin=0,
            zmax=max_pae,
        )
    )
    fig.update_layout(
    xaxis=dict(title="Scored Residue"),
    yaxis=dict(title="Aligned Residue"),
    )

    if save_image:
            image_path = f"{out_dir}/{name+('_' if name else '')}pae.png"
            fig.write_image(image_path, width=800, height=800)

    return fig
