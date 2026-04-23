#!/usr/bin/env python

import pickle
import os
import argparse
import json
#import torch moved to a conditional import since too bulky import if not used
import numpy as np
import csv
import string
from utils import plddt_from_struct_b_factor, get_chain_ids

# TODO: Issue #309, make into a proper separate process, it its own module so that dependencies can be managed better
# TODO: Need a sense of ranking, so that metrics can be traced back to correct model structure, even if they're not in sequential order. The enumerates() here are not sufficient.
#       Needs to be program-dependent, (see item below).
# TODO: look into have a --prog argument that could set filenames etc, logically seperate it?
# {name}_{prog}_{metric}.tsv might be easier for MultiQC to parse a complex workdir, than without the .prog
# TODO: read --prog from ${meta.model} in the NextFlow pipes. This also allows case switching in a proper EXTRACT_METRICS process.
# E.g. in main.nf of EXTACT_METRICS process, we could have:
# match ${meta.mode}:
#     case 'alphafold2':
#        ...
#     case 'rosettafold_all_atom':
#        ...
#...
# ^ overwrought with duplication, but can catch program specific weirdness, and lower barrier to adding new programs in the future.

# TODO: Chain-wise iPTM since the relevant interface might not always be the average of all.
# Would complete Issue #308
# Proposed format is pair-interfaces in rows, structure inference number in cols: https://github.com/nf-core/proteinfold/pull/312#issuecomment-2917709432
# KR - changed to have both sides of the matrix, because it's not symmetrical (see comment in Issue #306)

# Mapping of characters to integers for MSA parsing.
# 20 is for unknown characters, and 21 is for gaps.
AA_to_int = {
    "A": 0, "C": 1, "D": 2, "E": 3, "F": 4, "G": 5, "H": 6, "I": 7, "K": 8, "L": 9,
    "M": 10, "N": 11, "P": 12, "Q": 13, "R": 14, "S": 15, "T": 16, "V": 17, "W": 18, "Y": 19,
   ".": 20, "-": 21
}

def a3m_to_int(a3m_file):
    """
    Convert an A3M MSA representation into an integer representation (0-21).
    """
    with open(a3m_file, "r") as f:
        msa = f.read()

    # Convert each sequence in the MSA
    int_sequences = []
    for idx, line in enumerate(msa.splitlines()):
        if idx == 0 and not line.startswith(">"):  # If there's an additional header (non-FASTA) skip it. E.g ColabFold
            continue

        if not line.startswith(">"):  # Ignore header lines
            filtered_line = ''.join(char for char in line if not char.islower()) # Remove inserts (lower-case chars) in a3m
            int_sequence = [AA_to_int.get(char.upper(), 20) for char in filtered_line]
            int_sequences.append(int_sequence)

    int_sequences_array = np.array(int_sequences, dtype=object)
    return int_sequences_array

def format_msa_rows(msa_data):
    return [[str(x) for x in val] for val in msa_data]

def format_pae_rows(pae_data):
    return [[f"{num:.4f}" for num in row] for row in pae_data]

def format_iptm_rows(chain_pair_entries, chain_ids=None):
    """
    Format iPTM data into a list of rows for writing to a TSV file.
    Each row contains: the chain-pair in uppercase, e.g. "A:B", "B:A", A:C", etc. and then the iPTM value formatted to 4 decimal places.
    """
    def idx_to_letter(idx):
        """ Convert the index integer of the matrix to a letter representation that wraps to double representation, e.g. 0 -> A, 1 -> B, ..., 25 -> Z, 26 -> AA, 27 -> AB, etc.
            This is somewhat compatible with how protein structure chain names are numbered by biochemists.
            But we should move away from fixed-format PDB files -- we have nothing to lose but our chains."""
        result = ""
        while idx >= 0:
            result = string.ascii_uppercase[idx % 26] + result
            idx = idx // 26 - 1
            if idx < 0:
                break
        return result

    if chain_ids:
        #would be better with some model_id sorting
        iptm_rows = [[""]+[f"{chain_ids[idx[0]]}:{chain_ids[idx[1]]}" for idx, val in next(iter(chain_pair_entries.values()))]]
    else:
        iptm_rows = [[""]+[f"{idx_to_letter(idx[0])}:{idx_to_letter(idx[1])}" for idx, val in next(iter(chain_pair_entries.values()))]]

    for model_idx, chain_pair_entries_values in chain_pair_entries.items():
        iptm_rows.append([model_idx]+[f"{val:.4f}" for idx, val in chain_pair_entries_values])

    return [list(row) for row in zip(*iptm_rows)]


def format_pair_score_rows(pair_score_entries, pair_labels=None):
    if pair_labels is None:
        pair_labels = [label for label, _ in next(iter(pair_score_entries.values()))]

    rows = [[""] + pair_labels]
    for model_idx, score_values in pair_score_entries.items():
        score_map = {label: value for label, value in score_values}
        rows.append([model_idx] + [f"{score_map.get(label, 0.0):.4f}" for label in pair_labels])

    return [list(row) for row in zip(*rows)]


def chain_iptm_matrix_to_pairs(iptm_matrix):
    """
    Convert a chain-wise iPTM matrix to pair values by taking off-diagonal elements.
    """
    # From AlphaFold3 output docs:
    # 'chain_pair_iptm': An [num_chains, num_chains] array.
    # Off-diagonal element (i, j) of the array contains the ipTM restricted to tokens from chains i and j.
    # Diagonal element (i, i) contains the pTM restricted to chain i.
    return [(idx, val) for idx, val in np.ndenumerate(iptm_matrix) if idx[0] != idx[1]]

def chainwise_iptm_matrix_to_ptms(iptm_matrix):
    return [(idx, val) for idx, val in np.ndenumerate(iptm_matrix) if idx[0] == idx[1]]

def write_tsv(file_path, rows):
    with open(file_path, 'w') as out_f:
        writer = csv.writer(out_f, delimiter='\t')
        writer.writerows(rows)


def ptm_func(x, d0):
    return 1.0 / (1.0 + (x / d0) ** 2.0)


ptm_func_vec = np.vectorize(ptm_func)


def calc_d0(length, pair_type='protein'):
    length = float(length)
    min_value = 2.0 if pair_type == 'nucleic_acid' else 1.0
    if length > 27:
        d0 = 1.24 * (length - 15) ** (1.0 / 3.0) - 1.8
    else:
        d0 = 1.0
    return max(min_value, d0)


def parse_pdb_atom_line(line):
    residue_name = line[17:20].strip()
    if residue_name == "LIG":
        return None

    return {
        "atom_num": int(line[6:11].strip()),
        "atom_name": line[12:16].strip(),
        "residue_name": residue_name,
        "chain_id": line[21].strip(),
        "residue_seq_num": int(line[22:26].strip()),
        "x": float(line[30:38].strip()),
        "y": float(line[38:46].strip()),
        "z": float(line[46:54].strip()),
    }


def parse_cif_atom_line(line, fielddict):
    linelist = line.split()
    residue_seq_num = linelist[fielddict['label_seq_id']]
    if residue_seq_num == ".":
        return None

    chain_field = 'auth_asym_id' if 'auth_asym_id' in fielddict else 'label_asym_id'
    return {
        "atom_num": int(linelist[fielddict['id']]),
        "atom_name": linelist[fielddict['label_atom_id']],
        "residue_name": linelist[fielddict['label_comp_id']],
        "chain_id": linelist[fielddict[chain_field]],
        "residue_seq_num": int(residue_seq_num),
        "x": float(linelist[fielddict['Cartn_x']]),
        "y": float(linelist[fielddict['Cartn_y']]),
        "z": float(linelist[fielddict['Cartn_z']]),
    }


def classify_chains(chains, residue_types):
    nuc_residue_set = {"DA", "DC", "DT", "DG", "A", "C", "U", "G"}
    chain_types = {}
    _, first_idx = np.unique(chains, return_index=True)
    unique_chains = chains[np.sort(first_idx)]

    for chain in unique_chains:
        indices = np.where(chains == chain)[0]
        chain_residues = residue_types[indices]
        nuc_count = sum(residue in nuc_residue_set for residue in chain_residues)
        chain_types[chain] = 'nucleic_acid' if nuc_count > 0 else 'protein'

    return chain_types


def extract_structure_chain_arrays(struct_file):
    residues = []
    cb_residues = []
    chains = []
    atomsitefield_num = 0
    atomsitefield_dict = {}

    residue_set = {
        "ALA", "ARG", "ASN", "ASP", "CYS", "GLN", "GLU", "GLY", "HIS", "ILE",
        "LEU", "LYS", "MET", "PHE", "PRO", "SER", "THR", "TRP", "TYR", "VAL",
        "DA", "DC", "DT", "DG", "A", "C", "U", "G"
    }
    cif = struct_file.endswith(".cif")

    with open(struct_file, 'r') as handle:
        for line in handle:
            if line.startswith("_atom_site."):
                line = line.strip()
                _, fieldname = line.split(".")
                atomsitefield_dict[fieldname] = atomsitefield_num
                atomsitefield_num += 1
                continue

            if not (line.startswith("ATOM") or line.startswith("HETATM")):
                continue

            atom = parse_cif_atom_line(line, atomsitefield_dict) if cif else parse_pdb_atom_line(line)
            if atom is None:
                continue

            if atom['atom_name'] == "CA" or "C1" in atom['atom_name']:
                residues.append({
                    "coor": np.array([atom['x'], atom['y'], atom['z']]),
                    "res": atom['residue_name'],
                    "chainid": atom['chain_id'],
                    "resnum": atom['residue_seq_num'],
                })
                chains.append(atom['chain_id'])

            if atom['atom_name'] == "CB" or "C3" in atom['atom_name'] or (
                atom['residue_name'] == "GLY" and atom['atom_name'] == "CA"
            ):
                cb_residues.append({
                    "coor": np.array([atom['x'], atom['y'], atom['z']]),
                    "res": atom['residue_name'],
                    "chainid": atom['chain_id'],
                    "resnum": atom['residue_seq_num'],
                })
            elif atom['atom_name'] == "CA" and atom['residue_name'] not in residue_set:
                cb_residues.append({
                    "coor": np.array([atom['x'], atom['y'], atom['z']]),
                    "res": atom['residue_name'],
                    "chainid": atom['chain_id'],
                    "resnum": atom['residue_seq_num'],
                })

    if not residues:
        return None

    coordinates = np.array([res['coor'] for res in cb_residues or residues])
    chains = np.array(chains)
    residue_types = np.array([res['res'] for res in residues])
    _, first_idx = np.unique(chains, return_index=True)
    unique_chains = chains[np.sort(first_idx)]
    chain_dict = classify_chains(chains, residue_types)
    chain_pair_type = {
        chain1: {
            chain2: (
                'nucleic_acid'
                if chain_dict[chain1] == 'nucleic_acid' or chain_dict[chain2] == 'nucleic_acid'
                else 'protein'
            )
            for chain2 in unique_chains if chain1 != chain2
        }
        for chain1 in unique_chains
    }
    distances = np.sqrt(((coordinates[:, np.newaxis, :] - coordinates[np.newaxis, :, :]) ** 2).sum(axis=2))

    return residues, chains, unique_chains, chain_pair_type, distances


def calculate_ipsae_scores(pae_matrix, struct_file, pae_cutoff=10.0):
    structure_data = extract_structure_chain_arrays(struct_file)
    if structure_data is None:
        return 0.0, {}

    residues, chains, unique_chains, chain_pair_type, _ = structure_data
    numres = len(residues)

    if pae_matrix.shape[0] != numres or pae_matrix.shape[1] != numres:
        raise ValueError(
            f"PAE matrix shape {pae_matrix.shape} does not match residue count {numres} for {struct_file}"
        )

    ipsae_d0dom_asym = {
        chain1: {chain2: 0.0 for chain2 in unique_chains if chain1 != chain2}
        for chain1 in unique_chains
    }
    pair_scores = {}

    for chain1 in unique_chains:
        for chain2 in unique_chains:
            if chain1 == chain2:
                continue

            valid_pairs_matrix = np.outer(chains == chain1, chains == chain2) & (pae_matrix < pae_cutoff)
            residues_1 = np.sum(np.any(valid_pairs_matrix, axis=1))
            residues_2 = np.sum(np.any(valid_pairs_matrix, axis=0))
            n0dom = residues_1 + residues_2
            d0dom = calc_d0(n0dom, chain_pair_type[chain1][chain2])
            ptm_matrix_d0dom = ptm_func_vec(pae_matrix, d0dom)

            max_score = 0.0
            for i in range(numres):
                if chains[i] != chain1:
                    continue
                valid_pairs = valid_pairs_matrix[i]
                if valid_pairs.any():
                    score = float(ptm_matrix_d0dom[i, valid_pairs].mean())
                    if score > max_score:
                        max_score = score
            ipsae_d0dom_asym[chain1][chain2] = max_score

    max_ipsae = 0.0
    for i, chain1 in enumerate(unique_chains):
        for chain2 in unique_chains[i + 1:]:
            score = max(ipsae_d0dom_asym[chain1][chain2], ipsae_d0dom_asym[chain2][chain1])
            pair_scores[f"{chain1}:{chain2}"] = score
            max_ipsae = max(max_ipsae, score)

    ordered_pair_scores = sorted(pair_scores.items(), key=lambda item: item[0])
    return round(max_ipsae, 3), ordered_pair_scores


def calculate_iptm_scores(pae_matrix, struct_file):
    structure_data = extract_structure_chain_arrays(struct_file)
    if structure_data is None:
        return 0.0, []

    residues, chains, unique_chains, chain_pair_type, _ = structure_data
    numres = len(residues)

    if pae_matrix.shape[0] != numres or pae_matrix.shape[1] != numres:
        raise ValueError(
            f"PAE matrix shape {pae_matrix.shape} does not match residue count {numres} for {struct_file}"
        )

    iptm_d0chn_asym = {
        chain1: {chain2: 0.0 for chain2 in unique_chains if chain1 != chain2}
        for chain1 in unique_chains
    }
    pair_scores = {}

    for chain1 in unique_chains:
        for chain2 in unique_chains:
            if chain1 == chain2:
                continue

            n0chn = np.sum(chains == chain1) + np.sum(chains == chain2)
            d0chn = calc_d0(n0chn, chain_pair_type[chain1][chain2])
            ptm_matrix_d0chn = ptm_func_vec(pae_matrix, d0chn)

            max_score = 0.0
            valid_pairs = (chains == chain2)
            for i in range(numres):
                if chains[i] != chain1:
                    continue
                if valid_pairs.any():
                    score = float(ptm_matrix_d0chn[i, valid_pairs].mean())
                    if score > max_score:
                        max_score = score
            iptm_d0chn_asym[chain1][chain2] = max_score

    max_iptm = 0.0
    for i, chain1 in enumerate(unique_chains):
        for chain2 in unique_chains[i + 1:]:
            score = max(iptm_d0chn_asym[chain1][chain2], iptm_d0chn_asym[chain2][chain1])
            pair_scores[f"{chain1}:{chain2}"] = score
            max_iptm = max(max_iptm, score)

    ordered_pair_scores = sorted(pair_scores.items(), key=lambda item: item[0])
    return round(max_iptm, 3), ordered_pair_scores


def resolve_struct_for_model(struct_map, model_id):
    if model_id in struct_map:
        return struct_map[model_id]
    try:
        numeric_model_id = int(model_id)
    except (TypeError, ValueError):
        return None
    return struct_map.get(numeric_model_id, struct_map.get(numeric_model_id - 1))

def extract_structs_plddt_to_tsv(name, structures):
    """
    Write out a tsv file contain pLDDTs for reading by MultiQC in nf-core/proteinfold
    Uses utils function with BioPython PDB package to extract residue pLDDT values from the b-factor column.
    """
    plddt_cols = [plddt_from_struct_b_factor(structure) for structure in structures]
    res_counts = [len(plddt_col) for plddt_col in plddt_cols]

    if len(set(res_counts)) != 1:
        raise ValueError("Not all structures have the same number of residues!")

    rank_names = [f"rank_{i}" for i in range(len(structures))]
    # Create header as the first row
    plddt_rows =  [["Positions"] + rank_names]
    res_id_col = list(range(len(plddt_cols[0])))
    plddt_rows.extend(zip(res_id_col, *plddt_cols))  # Combine lists column-wise to make rows
    write_tsv(f"{name}_plddt.tsv", plddt_rows)

def read_pkl(name, pkl_files, struct_files=None):
    """
    Adapted from the Galaxy AlphaFold tool (https://github.com/usegalaxy-au/tools-au/blob/de94df520c8dc7b8652aedb92e90f6ebb312f95f/tools/alphafold/scripts/outputs.py), originally authored by @neoformit and @graceahall and funded by Australian Biocommons and QCIF Australia.
    """
    ptm_data = {}
    iptm_data = {}
    ipsae_data = {}
    chainwise_iptm = {}
    chainwise_ipsae = {}
    struct_map = {}
    if struct_files:
        for idx, struct_file in enumerate(sorted(struct_files)):
            struct_map[idx] = struct_file
    for pkl_file in pkl_files:
        print(f"Processing {pkl_file}")
        data = pickle.load(open(pkl_file, "rb"))

        # Process MSA data
        if pkl_file.endswith("final_features.pkl"): # HelixFold3 - This one must be first
            write_tsv(f"{name}_msa.tsv", format_msa_rows(data["feat"]["msa"]))
        elif pkl_file.endswith("features.pkl"): # AlphaFold2.3
            try:
                N = data["num_alignments"][0] #monomer
            except:
                N = data["num_alignments"] #multimer
            write_tsv(f"{name}_msa.tsv", format_msa_rows(data["msa"][:N]))
        else:
            model_info = os.path.basename(pkl_file).replace("result_", "").replace(".pkl", "")
            #TODO: Make this explicit input
            with open(os.path.join(os.path.dirname(pkl_file),"ranking_debug.json")) as f:
                ranking_data = json.load(f)['order']
            model_id = ranking_data.index(model_info)
            if 'predicted_aligned_error' not in data.keys():
                print(f"No PAE output in {pkl_file}, it was likely a monomer calculation")
            else:
                write_tsv(f"{name}_{model_id}_pae.tsv", format_pae_rows(data["predicted_aligned_error"]))

            if 'ptm' not in data.keys():
                print(f"No pTM/iPTM output in {pkl_file}, it was likely a monomer calculation")
            else:
                ptm_data[model_id] = f"{np.round(data['ptm'],3)}\n"

            if 'iptm' in data:
                iptm_data[model_id] = f"{np.round(data['iptm'],3)}\n"

            struct_file = resolve_struct_for_model(struct_map, model_id)
            if 'predicted_aligned_error' in data.keys() and struct_file:
                try:
                    max_iptm, pair_iptm_scores = calculate_iptm_scores(np.array(data['predicted_aligned_error']), struct_file)
                    if pair_iptm_scores:
                        chainwise_iptm[model_id] = pair_iptm_scores
                    if model_id not in iptm_data and max_iptm > 0:
                        iptm_data[model_id] = f"{max_iptm:.3f}\n"
                except ValueError as e:
                    print(f"Skipping derived iPTM for {pkl_file}: {e}")

                max_ipsae, pair_scores = calculate_ipsae_scores(np.array(data['predicted_aligned_error']), struct_file)
                ipsae_data[model_id] = f"{max_ipsae:.3f}\n"
                if pair_scores:
                    chainwise_ipsae[model_id] = pair_scores
    if ptm_data:
        ptm_rows = sorted([[k, v.strip()] for k, v in ptm_data.items()], key=lambda x: x[0])
        write_tsv(f"{name}_ptm.tsv", ptm_rows)

    if iptm_data:
        iptm_rows = sorted([[k, v.strip()] for k, v in iptm_data.items()], key=lambda x: x[0])
        write_tsv(f"{name}_iptm.tsv", iptm_rows)

    if chainwise_iptm:
        write_tsv(f"{name}_chainwise_iptm.tsv", format_pair_score_rows(chainwise_iptm))

    if ipsae_data:
        ipsae_rows = sorted([[k, v.strip()] for k, v in ipsae_data.items()], key=lambda x: x[0])
        write_tsv(f"{name}_ipsae.tsv", ipsae_rows)

    if chainwise_ipsae:
        write_tsv(f"{name}_chainwise_ipsae.tsv", format_pair_score_rows(chainwise_ipsae))

def read_paired_a3m(name, a3m_file):
    msa_rows = a3m_to_int(a3m_file)
    write_tsv(f"{name}_msa.tsv", format_msa_rows(msa_rows))

def read_a3m(name, a3m_files):
    # RosettaFold-All-Atom
    #TODO: DRY with unpaired below for Boltz
    msa_rows = {}
    for a3m_file in a3m_files: #Should already be alphabetical by chain
        msa_rows[a3m_file] = a3m_to_int(a3m_file)

    final_rows = []
    temp_row = []
    for a3m_file in a3m_files:
        temp_row.extend(msa_rows[a3m_file][0])
    final_rows.append(temp_row)

    # Un-paired TODO: get pairing code from RF-AA source
    # https://github.com/baker-laboratory/RoseTTAFold-All-Atom/blob/main/rf2aa/data/parsers.py#L405
    msa_widths = [len(msa_rows[chain][0]) for chain in a3m_files]
    msa_heights = [len(msa_rows[chain]) for chain in a3m_files]

    cum_total_rows = np.cumsum(msa_heights)
    for row_idx in range(cum_total_rows[-1]):
        temp_row = []

        for i, chain in enumerate(a3m_files):
            msa = msa_rows[chain]
            width = msa_widths[i]
            if i == 0:
                minrow = 0
            else:
                minrow = cum_total_rows[i-1]
            maxrow = cum_total_rows[i]

            if minrow <= row_idx < maxrow:
                msa_row_idx = row_idx - minrow
                temp_row.extend(msa[msa_row_idx])
            else:
                temp_row.extend(["21"] * width) #gap
        final_rows.append(temp_row)

    write_tsv(f"{name}_msa.tsv", format_msa_rows(final_rows))

def read_npz(name, npz_files, struct_files=None):
   ipsae_rows = []
   chainwise_ipsae = {}
   struct_map = {}
   if struct_files:
        for idx, struct_file in enumerate(sorted(struct_files)):
            struct_map[idx] = struct_file
   for idx, npz_file in enumerate(npz_files):
        data = np.load(npz_file)
       #Boltz PAE files if --write_full_pae is used
        if npz_file.split('/')[-1].startswith('pae') and npz_file.endswith('.npz'):
            model_id = os.path.basename(npz_file).split('_model_')[-1].split('.npz')[0]
            write_tsv(f"{name}_{model_id}_pae.tsv", format_pae_rows(data["pae"]))
            struct_file = resolve_struct_for_model(struct_map, model_id)
            if struct_file:
                try:
                    max_ipsae, pair_scores = calculate_ipsae_scores(np.array(data["pae"]), struct_file)
                    ipsae_rows.append((f"{model_id}", f"{max_ipsae:.3f}"))
                    if pair_scores:
                        chainwise_ipsae[int(model_id)] = pair_scores
                except ValueError as e:
                    print(f"Skipping ipSAE for {npz_file}: {e}")
   if len(ipsae_rows) > 0:
        write_tsv(f"{name}_ipsae.tsv", sorted(ipsae_rows, key=lambda x: int(x[0])))
   if len(chainwise_ipsae) > 0:
        write_tsv(f"{name}_chainwise_ipsae.tsv", format_pair_score_rows(dict(sorted(chainwise_ipsae.items(), key=lambda x: x[0]))))

# Boltz MSA processing
def read_csv(name, csv_files):
    if not os.path.isfile(csv_files[0]): return #TODO: Fix temporary workaround
    msa_rows = {}
    unpaired_msa_rows = {}
    for csv_file in sorted(csv_files, key=lambda x: int(x.split('_')[-1].split('.csv')[0])):
        msa_lines = []
        unpaired_msa_lines = []
        with open(csv_file) as f:
            f.readline()
            for line in f:
                if line.split(',')[0] == '-1' and len(csv_files)>1: #Server MSA appears as un-paired
                    unpaired_msa_lines.append(''.join(c for c in line.strip('\n').split(',')[1] if not c.islower()))
                else:
                    msa_lines.append(''.join(c for c in line.strip('\n').split(',')[1] if not c.islower()))
        msa_rows[csv_file.split('_')[-1].split('.csv')[0]] = [[str(AA_to_int.get(residue, 20)) for residue in line] for line in msa_lines]
        unpaired_msa_rows[csv_file.split('_')[-1].split('.csv')[0]] = [[str(AA_to_int.get(residue, 20)) for residue in line] for line in unpaired_msa_lines]

    # Get Chain to MSA mapping (ie non-redundant for homomers)
    # TODO: Make this explicit input
    with open(f'boltz_results_{name}/processed/manifest.json') as f:
        manifest = json.load(f)

    final_rows = []
    # Paired
    for i in range(len(msa_rows["0"])): #The number of paired lines is common to all MSAs
        temp_row = []
        #This needs to be fixed if inference is batched in future.
        for chain in manifest["records"][0]["chains"]:
            j = chain["msa_id"].split("_")[-1]
            temp_row.extend(msa_rows[j][i])
        final_rows.append(temp_row)

    # Un-paired
    msa_widths = [len(msa_rows[chain["msa_id"].split("_")[-1]][0]) for chain in manifest["records"][0]["chains"]]
    msa_heights = [len(unpaired_msa_rows[chain["msa_id"].split("_")[-1]]) for chain in manifest["records"][0]["chains"]]

    cum_total_rows = np.cumsum(msa_heights)

    for row_idx in range(cum_total_rows[-1]):
        temp_row = []

        for i, chain in enumerate(manifest["records"][0]["chains"]):
            msa = unpaired_msa_rows[chain["msa_id"].split("_")[-1]]
            width = msa_widths[i]
            if i == 0:
                minrow = 0
            else:
                minrow = cum_total_rows[i-1]
            maxrow = cum_total_rows[i]

            if minrow <= row_idx < maxrow:
                msa_row_idx = row_idx - minrow
                temp_row.extend(msa[msa_row_idx])
            else:
                temp_row.extend(["21"] * width) #gap
        final_rows.append(temp_row)

    write_tsv(f"{name}_msa.tsv", final_rows)

def read_json(name, json_files, struct_files=None):
    ptm_data = {}
    iptm_data = {}
    ipsae_data = {}
    chainwise_iptm = {}
    chainwise_ipsae = {}
    chain_pair_iptm_data = {} # For iPTM data to be converted into formatted pairs with non-self elements
    chain_pair_entries = {}
    chainwise_ptms = {}
    chain_ids = []
    struct_map = {}
    if struct_files:
        for idx, struct_file in enumerate(sorted(struct_files)):
            struct_map[idx] = struct_file

    for idx, json_file in enumerate(json_files):
        with open(json_file, 'r') as f:
            data = json.load(f)
            if json_file.endswith("_data.json"): #AF3 output with MSA info
                # Can't just used format_msa_rows since there's FASTA headers in the json content
                paired_msa_rows = []
                unpaired_msa_rows = []
                for chain in data['sequences']:
                    unpaired_MSA = chain['protein']['unpairedMsa']
                    unpaired_msa_lines = [''.join(c for c in line if not c.islower()) for line in unpaired_MSA.split("\n") if line.strip() and not line.startswith(">")]
                    unpaired_msa_rows.append([[str(AA_to_int.get(residue, 20)) for residue in line] for line in unpaired_msa_lines])
                    paired_MSA = chain['protein']['pairedMsa']
                    paired_msa_lines = [''.join(c for c in line if not c.islower()) for line in paired_MSA.split("\n") if line.strip() and not line.startswith(">")]
                    paired_msa_rows.append([[str(AA_to_int.get(residue, 20)) for residue in line] for line in paired_msa_lines])

                chains = len(data['sequences'])
                final_rows = []
                # Paired
                for i in range(len(paired_msa_rows[0])): #The number of paired lines is common to all MSAs
                    temp_row = []
                    #This needs to be fixed if inference is batched in future.
                    for j in range(chains):
                        temp_row.extend(paired_msa_rows[j][i])
                    final_rows.append(temp_row)

                # Un-paired
                msa_widths = [len(paired_msa_rows[chain][0]) for chain in range(chains)]
                msa_heights = [len(unpaired_msa_rows[chain]) for chain in range(chains)]

                cum_total_rows = np.cumsum(msa_heights)

                for row_idx in range(cum_total_rows[-1]):
                    temp_row = []

                    for i in range(chains):
                        msa = unpaired_msa_rows[i]
                        width = msa_widths[i]
                        if i == 0:
                            minrow = 0
                        else:
                            minrow = cum_total_rows[i-1]
                        maxrow = cum_total_rows[i]
                        if minrow <= row_idx < maxrow:
                            msa_row_idx = row_idx - minrow
                            temp_row.extend(msa[msa_row_idx])
                        else:
                            temp_row.extend(["21"] * width) #gap
                    final_rows.append(temp_row)
                write_tsv(f"{name}_msa.tsv", final_rows)
            #AF3 output with PAE info, or HF3 PAE data. TODO: Need to make sure the workflow points to [protein]/[protein]_rank1/all_results.json

            # TODO: I think I need to capture model_id and inference_id  -- MUST FIX since this is so fragile and will be different for different programs.
            #if '_alphafold2_ptm_model_' in json_file: # ColabFold, multimer or monomer
            ## Might want to cut more if I just want ${meta.id}_[metric].tsv
            #    model_id = os.path.basename(json_file)
            #    print(model_id)
            if 'all_results' in json_file: # Individual predictions in HF3
                model_id = int(os.path.dirname(json_file).split('-rank')[-1]) #Use re-ranked output
            if 'predictions' in json_file: # Boltz-1 confidences in predictions/[protein]/confidence_[protein]_model_*.json
            # TODO: haven't tested this for multiple models with --diffusion_samples
                model_id = os.path.basename(json_file).split('_model_')[-1].split('.json')[0]
            #TODO: Fix this for AF3 - the top-ranked files are in the top-level directory
            if 'confidences' in json_file: #Prevent crash when model_id is not defined
                #model_id = os.path.basename(json_file).split('confidences_')[-1].split('.json')[0]
                model_id = 0

            if "pae" not in data.keys():
                print(f"No PAE output in {json_file}, it was likely a monomer calculation")
            else:
                write_tsv(f"{name}_{model_id}_pae.tsv", format_pae_rows(data["pae"]))

            if 'ptm' not in data.keys():
                print(f"No pTM/iPTM output in {json_file}, it was likely a monomer calculation")
                #This message should change - currently called on boltz files not expected to contain ptm
            else:
                ptm_data[model_id] = f"{np.round(data['ptm'],3)}\n"

            if 'iptm' not in data.keys():
                print(f"No pTM/iPTM output in {json_file}, it was likely a monomer calculation")
            else:
                if data['iptm']: #ie not null
                    iptm_data[model_id] = f"{np.round(data['iptm'],3)}\n"

            struct_file = resolve_struct_for_model(struct_map, model_id)
            if "pae" in data.keys() and struct_file:
                try:
                    max_iptm, pair_iptm_scores = calculate_iptm_scores(np.array(data['pae']), struct_file)
                    if pair_iptm_scores and model_id not in chain_pair_entries:
                        chainwise_iptm[model_id] = pair_iptm_scores
                    if model_id not in iptm_data and max_iptm > 0:
                        iptm_data[model_id] = f"{max_iptm:.3f}\n"

                    max_ipsae, pair_scores = calculate_ipsae_scores(np.array(data['pae']), struct_file)
                    ipsae_data[model_id] = f"{max_ipsae:.3f}\n"
                    if pair_scores:
                        chainwise_ipsae[model_id] = pair_scores
                except ValueError as e:
                    print(f"Skipping ipSAE for {json_file}: {e}")

            if 'chain_pair_iptm' not in data.keys() and 'pair_chains_iptm' not in data.keys():
                print(f"No chain-wise iPTM output in {json_file}, it was likely a monomer calculation")
            else:
                if 'chain_pair_iptm' in data.keys():
                    chain_pair_iptm_data = data['chain_pair_iptm']
                    chain_iptm_matrix = np.array(chain_pair_iptm_data)
                elif 'pair_chains_iptm' in data.keys(): #Boltz key
                    chain_pair_iptm_data = data['pair_chains_iptm']
                    # casting to int works for sorting boltz - need to carefully check other modes
                    chain_iptm_matrix = np.array([[chain_pair_iptm_data[row][col] for col in sorted(chain_pair_iptm_data[row], key=int)] for row in sorted(chain_pair_iptm_data, key=int)])
                    basename = os.path.basename(json_file)
                    dirname = os.path.dirname(json_file)
                    pdb_name = ".".join(basename[11:].split('.')[:-1])+'.pdb' #TODO: Fix magic number
                    chain_ids = get_chain_ids(os.path.join(dirname,pdb_name))
                else:
                    raise ValueError("No chain-wise iPTM data found in the JSON file.")

                chain_pair_entries[model_id] = chain_iptm_matrix_to_pairs(chain_iptm_matrix)
                chainwise_ptms[model_id] = chainwise_iptm_matrix_to_ptms(chain_iptm_matrix)

    if chainwise_ptms:
        write_tsv(f"{name}_chainwise_ptm.tsv", format_iptm_rows(chainwise_ptms, chain_ids=chain_ids))

    if chain_pair_entries:
        write_tsv(f"{name}_chainwise_iptm.tsv", format_iptm_rows(chain_pair_entries, chain_ids=chain_ids))
    elif chainwise_iptm:
        write_tsv(f"{name}_chainwise_iptm.tsv", format_pair_score_rows(chainwise_iptm))

    if ptm_data:
        ptm_rows = [[k, v.strip()] for k, v in sorted(ptm_data.items(), key=lambda x: x[0])]
        write_tsv(f"{name}_ptm.tsv", ptm_rows)

    if iptm_data:
        iptm_rows = [[k, v.strip()] for k, v in sorted(iptm_data.items(), key=lambda x: x[0])]
        write_tsv(f"{name}_iptm.tsv", iptm_rows)

    if ipsae_data:
        ipsae_rows = [[k, v.strip()] for k, v in sorted(ipsae_data.items(), key=lambda x: x[0])]
        write_tsv(f"{name}_ipsae.tsv", ipsae_rows)

    if chainwise_ipsae:
        write_tsv(f"{name}_chainwise_ipsae.tsv", format_pair_score_rows(chainwise_ipsae))


def read_pt(name, pt_files):
    import torch # moved to a conditional import since too bulky import if not used
    #TODO: Handle this better when refactored - Is this just RFAA??
    for pt_file in pt_files:
        with open(pt_file, 'rb') as f:   # TODO: point to [protein]_aux.pt
            data = torch.load(f, map_location="cpu")
            if 'pae' in data:
                # The pt file contains a tensor that needs to be cast as an array
                # Squeeze leading dimension (batch?)
                write_tsv(f"{name}_0_pae.tsv", format_pae_rows(np.squeeze(data["pae"].numpy())))
        break

def read_colabfold_metrics(name, colabfold_metrics_fns, struct_files=None):
    ptm_rows = []
    iptm_rows = []
    ipsae_rows = []
    chainwise_iptm = {}
    chainwise_ipsae = {}
    struct_map = {}
    if struct_files:
        for idx, struct_file in enumerate(sorted(struct_files)):
            struct_map[idx] = struct_file
    for fn in colabfold_metrics_fns:
        with open(fn) as f:
            data = json.load(f)
        rank_id = int(fn.split("rank_")[1].split("_")[0])-1
        model_id = int(fn.split("model_")[1].split("_")[0])
        seed_id = int(fn.split("seed_")[1].split(".")[0])
        if "pae" in data:
            write_tsv(f"{name}_{rank_id}_pae.tsv", format_pae_rows(data["pae"]))
        if "ptm" in data:
            ptm_rows.append((f"{rank_id}", data["ptm"]))
        if "iptm" in data:
            iptm_rows.append((f"{rank_id}", data["iptm"]))
        struct_file = resolve_struct_for_model(struct_map, rank_id)
        if "pae" in data and struct_file:
            max_iptm, pair_iptm_scores = calculate_iptm_scores(np.array(data['pae']), struct_file)
            if pair_iptm_scores:
                chainwise_iptm[rank_id] = pair_iptm_scores
            if not any(row[0] == f"{rank_id}" for row in iptm_rows) and max_iptm > 0:
                iptm_rows.append((f"{rank_id}", f"{max_iptm:.3f}"))

            max_ipsae, pair_scores = calculate_ipsae_scores(np.array(data['pae']), struct_file)
            ipsae_rows.append((f"{rank_id}", f"{max_ipsae:.3f}"))
            if pair_scores:
                chainwise_ipsae[rank_id] = pair_scores
    if len(ptm_rows)>0:
        write_tsv(f"{name}_ptm.tsv", sorted(ptm_rows, key = lambda x: x[0]))
    if len(iptm_rows)>0:
        write_tsv(f"{name}_iptm.tsv", sorted(iptm_rows, key = lambda x: x[0]))
    if len(chainwise_iptm)>0:
        write_tsv(f"{name}_chainwise_iptm.tsv", format_pair_score_rows(dict(sorted(chainwise_iptm.items(), key=lambda x: x[0]))))
    if len(ipsae_rows)>0:
        write_tsv(f"{name}_ipsae.tsv", sorted(ipsae_rows, key = lambda x: x[0]))
    if len(chainwise_ipsae)>0:
        write_tsv(f"{name}_chainwise_ipsae.tsv", format_pair_score_rows(dict(sorted(chainwise_ipsae.items(), key=lambda x: x[0]))))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pkls", dest="pkls", required=False, nargs="+") # For reading both HelixFold3 and AlphaFold2 MSA formats
    parser.add_argument("--npzs", dest="npzs", required=False, nargs="+") # For reading the Boltz-1 PAE formats. TODO: Boltz-1 MSA not implemented (go straight to .a3m file), implement
    parser.add_argument("--a3ms", dest="a3ms", required=False, nargs="+") # For reading the RosettaFold-All-Atom MSA formats
    parser.add_argument("--paired_a3m", dest="paired_a3m", required=False) # For reading the ColabFold MSA format
    parser.add_argument("--csvs", dest="csvs", required=False, nargs="+") # For reading boltz csvs
    parser.add_argument("--jsons", dest="jsons", required=False, nargs="+") # For reading the AF3 MSA & PAE, HF3 PAE
    parser.add_argument("--colabfold_metrics_fns", required=False, nargs="+")
    parser.add_argument("--pts", dest="pts", required=False, nargs="+") # For read RFAA pytorch model to get PAE data
    parser.add_argument("--structs", dest="structs", required=False, nargs="+")
    parser.add_argument("--name", default="untitled", dest="name") # might need a --name $meta.id
    args = parser.parse_args()

    if args.pkls:
        read_pkl(args.name, args.pkls, args.structs)
    if args.a3ms:
        read_a3m(args.name, args.a3ms)
    if args.paired_a3m:
        read_paired_a3m(args.name, args.paired_a3m)
    if args.csvs:
        read_csv(args.name, args.csvs)
    if args.npzs:
        read_npz(args.name, args.npzs, args.structs)
    if args.jsons:
        read_json(args.name, args.jsons, args.structs)
    if args.pts:
        read_pt(args.name, args.pts)
    if args.structs:
        extract_structs_plddt_to_tsv(args.name, args.structs)
    if args.colabfold_metrics_fns:
        read_colabfold_metrics(args.name, args.colabfold_metrics_fns, args.structs)

if __name__ == "__main__":
    main()
