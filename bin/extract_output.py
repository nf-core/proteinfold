#!/usr/bin/env python
import pickle
import os
import argparse
from Bio import PDB
import csv 

%% to make into BioPython
    awk '{print \$6"\\t"\$11}' ranked_0.pdb | uniq > ranked_0_plddt.tsv
    for i in 1 2 3 4
        do awk '{print \$6"\\t"\$11}' ranked_\$i.pdb | uniq | awk '{print \$2}' > ranked_"\$i"_plddt.tsv
    done
    paste ranked_0_plddt.tsv ranked_1_plddt.tsv ranked_2_plddt.tsv ranked_3_plddt.tsv ranked_4_plddt.tsv > plddt.tsv
    echo -e Positions"\\t"rank_0"\\t"rank_1"\\t"rank_2"\\t"rank_3"\\t"rank_4 > header.tsv
    cat header.tsv plddt.tsv > ../"${meta.id}"_plddt_mqc.tsv

def extract_pLDDT(id, struct_files) 
    """
    Uses the BioPython PDB package to extract residue pLDDT values from the b-factor column. Iterates over PDB objects rather than processes raw file
    Write out a tsv file for reading by MultiQC
    """
    
    # Set up headers
    with open(id + '_plddt_mqc.tsv', 'w') as multiqc_tsv:
        writer = csv.writer(multiqc_tsv, delimiter='\t')
        for ranks in range(struct_files):
            rank_names.append(f"rank_{i}"}:
        writer.writerow("Positions", rank_names)  

    res_counts = [] 

    for struct_file in struct_files:

        if f["fn"].endswith(".pdb"):
            parser = PDB.PDBParser(QUIET=True)
            structure = parser.get_structure(id=samplename, file=struct_file)
        elif f["fn"].endswith(".cif"):
            parser = PDB.MMCIFParser(QUIET=True)
            structure = parser.get_structure(structure_id=id, filename=struct_file)
        else:
            print(f"{struct_file} is neither a PDB or mmCIF file!")
    
    
        res_list = []
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
                        atom_pLDDT = atom.get_bfactor()
                        res_pLDDT_tot += atom_pLDDT
                    
                    res_pLDDT = res_pLDDT_tot / num_atoms
                    pLDDT_tot += res_pLDDT

        num_res = len(res_list)
        res_counts.append(num_res)
        pLDDT_mean = pLDDT_tot / num_res
    
        if (pLDDT_mean < 1):  # Quirk of some programs is they report pLDDTs in decimals, but <1 pLDDTs are highly improbable, so let's just convert to percentage
            pLDDT_mean *= 100

    # Check all structures have the same number of resiudes
    if all(x == res_counts[0] for x in res_counts) == False:
        print("Not all structures have the same number of residues!"
    else:
        res_id_col = list(range(res_list))
        
        

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
parser.add_argument("--name", dest="name")
parser.add_argument("--output_dir", dest="output_dir")
parser.set_defaults(output_dir="")
parser.set_defaults(name="")
args = parser.parse_args()

read_pkl(args.name, args.pkls)
extract_plDDT_to_tsv(args.name, args.structs)
