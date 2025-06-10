import importlib.util
import numpy as np
bio_is_installed = importlib.util.find_spec("Bio") is not None

def _convert_plddt_to_100(res_plddt):
    if (res_plddt < 1):  # Converting to a [0,100] range
        res_plddt *= 100
    return res_plddt


def plddt_from_struct_b_factor_adhoc(struct_file):
    """
    Uses ad hoc PDB parser to extract residue pLDDT values from the b-factor column. Iterates over PDB objects rather than processes raw file
    """
    #NOTE: this is a temporary hack which is not robust as a general parser.
    #Should be temporary - need to check with non-protein entities
    if not str(struct_file).endswith(".pdb"):
        raise ValueError(f"{struct_file} must be a PDB file!")

    res_plddts = []
    resid_prev = -1
    atom_plddt_list = []

    with open(struct_file) as f:
        for line in f:
            if not line.startswith('ATOM'): continue
            resid = int(line[23:26].strip())
            if resid == resid_prev:
                atom_plddt_list.append(float(line[61:66].strip()))
            else:
                if resid_prev == -1:
                    resid_prev = resid
                    continue
                res_plddt = sum(atom_plddt_list)/len(atom_plddt_list)
                res_plddt = _convert_plddt_to_100(res_plddt)
                res_plddts.append(res_plddt)
                resid_prev = resid

                # Reset atom tracking
                atom_plddt_list = []
                atom_plddt_list.append(float(line[61:66].strip()))

        res_plddt = sum(atom_plddt_list)/len(atom_plddt_list)
        res_plddt = _convert_plddt_to_100(res_plddt)
        res_plddts.append(res_plddt)

    res_plddts = np.array(res_plddts)
    res_plddts = np.round(res_plddts, 2)

    return res_plddts


def plddt_from_struct_b_factor_biopython(struct_file):
    """
    Uses the BioPython PDB package to extract residue pLDDT values from the b-factor column. Iterates over PDB objects rather than processes raw file
    """
    from Bio import PDB
    if str(struct_file).endswith(".pdb"):
        parser = PDB.PDBParser(QUIET=True)
        structure = parser.get_structure(id=id, file=struct_file)
    elif str(struct_file).endswith(".cif"):
        parser = PDB.MMCIFParser(QUIET=True)
        structure = parser.get_structure(structure_id=id, filename=struct_file)
    else:
        raise ValueError(f"{struct_file} is neither a PDB or mmCIF file!")

#    res_list = []
    res_plddts = []
#    plddt_tot = 0

    for model in structure:
        for chain in model:
            chain_res_list = chain.get_unpacked_list()
#            res_list.extend(chain_res_list)
            for residue in chain:
                atom_list = residue.get_unpacked_list()
                atom_plddt_tot = 0
                for atom in residue:  # ESMFold and others have separate atom-wise values, so doing atom-wise to cover that and residue-wise
                    atom_plddt = atom.get_bfactor()
                    atom_plddt_tot += atom_plddt

                res_plddt = float(atom_plddt_tot / len(atom_list))

                if (res_plddt < 1):  # RFAA the multiplication of mean isn't failing. Anyway covering to a [0,100] range for any structure file1
                    res_plddt *= 100
                res_plddt = _convert_plddt_to_100(res_plddt)

                res_plddts.append(res_plddt)
#                plddt_tot += res_plddt

    res_plddts = np.array(res_plddts)
    res_plddts = np.round(res_plddts, 2)

    return res_plddts

if bio_is_installed:
    plddt_from_struct_b_factor = plddt_from_struct_b_factor_biopython
else:
    plddt_from_struct_b_factor = plddt_from_struct_b_factor_adhoc
