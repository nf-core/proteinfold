#!/usr/bin/env python
import pickle
import os
import argparse
from Bio import PDB
import csv 

def extract_struct_pLDDT_to_tsv(id, struct_files): 
    """
    Uses the BioPython PDB package to extract residue pLDDT values from the b-factor column. Iterates over PDB objects rather than processes raw file
    Write out a tsv file for reading by MultiQC
    """
    
    # Set up headers
    with open(id + '_plddt_mqc.tsv', 'w') as multiqc_tsv:
        writer = csv.writer(multiqc_tsv, delimiter='\t')
        rank_names = []
        for i in range(len(struct_files)):
            rank_names.append(f"rank_{i}")
        writer.writerow(["Positions"] + rank_names)  

    res_counts = [] 
    pLDDT_cols = []    

    for struct_file in struct_files:
        
        if str(struct_file).endswith(".pdb"):
            parser = PDB.PDBParser(QUIET=True)
            structure = parser.get_structure(id=id, file=struct_file)
        elif str(struct_file).endswith(".cif"):
            parser = PDB.MMCIFParser(QUIET=True)
            structure = parser.get_structure(structure_id=id, filename=struct_file)
        else:
            print(f"{struct_file} is neither a PDB or mmCIF file!")
    
    
        res_list = []
        res_pLDDTs = [] # should probably use a numpy array
        pLDDT_tot = 0

        for model in structure:
            for chain in model:
                chain_res_list = chain.get_unpacked_list()
                res_list.extend(chain_res_list)
                for residue in chain:
                    atom_list = residue.get_unpacked_list()
                    num_atoms = len(atom_list)
                    res_pLDDT_tot = 0
                    for atom in residue:  # ESMFold and others have separate atom-wise values, so doing atom-wise to cover that and residue-wise
                        atom_pLDDT = round(float(atom.get_bfactor()),2)
                        res_pLDDT_tot += atom_pLDDT
                    
                    res_pLDDT = round(float(res_pLDDT_tot / num_atoms),2)
                    res_pLDDTs.append(res_pLDDT)
                    pLDDT_tot += res_pLDDT

        
        num_res = len(res_list)
        res_counts.append(num_res)
        pLDDT_mean = pLDDT_tot / num_res
    
        if (pLDDT_mean < 1):  # Quirk of some programs is they report pLDDTs in decimals, but <1 pLDDTs are highly improbable, so let's just convert to percentage
            pLDDT_mean *= 100

        pLDDT_cols.append(res_pLDDTs)

    # Check all structures have the same number of resiudes
    if all(x == res_counts[0] for x in res_counts) == False:
        print("Not all structures have the same number of residues!")
    else:
        res_id_col = list(range(len(res_list)))
   
    # Check the pLDDT cols are the same size before combining
    if (len(set(len(col) for col in pLDDT_cols)) == 1) == False:
        print("Not all pLDDT columns have the same number of values!")
 
    pLDDT_rows = zip(res_id_col, *pLDDT_cols) #combine lists column-wise to make rows
    
    with open(id + '_plddt_mqc.tsv', 'a') as multiqc_tsv:
        writer = csv.writer(multiqc_tsv, delimiter='\t')
        for pLDDT_row in pLDDT_rows:
            writer.writerow(pLDDT_row)
    

def read_pkl(id, pkl_files):
    for pkl_file in pkl_files:
        dict_data = pickle.load(open(pkl_file, "rb"))
        if pkl_file.endswith("features.pkl"):
            with open(f"{id}_msa.tsv", "w") as out_f:
                for val in dict_data["msa"]:
                    out_f.write("\t".join([str(x) for x in val]) + "\n")
        else:
            model_id = (
                os.path.basename(pkl_file)
                .replace("result_model_", "")
                .replace("_pred_0.pkl", "")
            )
            with open(f"{id}_lddt_{model_id}.tsv", "w") as out_f:
                out_f.write("\t".join([str(x) for x in dict_data["plddt"]]) + "\n")


parser = argparse.ArgumentParser()
parser.add_argument("--pkls", dest="pkls", required=True, nargs="+")
parser.add_argument("--structs", dest="structs", required=True, nargs="+")
parser.add_argument("--name", dest="name") # might need a --name $meta.id 
parser.add_argument("--output_dir", dest="output_dir")
parser.set_defaults(output_dir="")
parser.set_defaults(name="")
args = parser.parse_args()

read_pkl(args.name, args.pkls)
extract_struct_pLDDT_to_tsv(args.name, args.structs)
