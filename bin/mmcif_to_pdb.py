#!/usr/bin/env python

###############################################################################
###############################################################################
## Created on December 16th 2024 convert cif files to pdb
###############################################################################
###############################################################################

import argparse
import sys
from Bio import PDB

def parse_args(args=None):
    Description = "Convert mmcif files to pdb format."
    Epilog = """Example usage: python mmcif_to_pdb.py <MMCIF_IN>"""

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument(
        "MMCIF_IN",
        help="Input mmcif file."
    )
    parser.add_argument(
        "-po",
        "--pdb_out",
        type=str,
        dest="PDB_OUT",
        default="",
        help="Output pdb file."
    )
    return parser.parse_args(args)


def mmcif_to_pdb(mmcif_file, pdb_file):
    """
    Convert an mmCIF file to PDB format.
    """
    # Parse the mmCIF file
    parser = PDB.MMCIFParser(QUIET=True)
    structure = parser.get_structure("structure", mmcif_file)

    # Write to PDB format
    io = PDB.PDBIO()
    io.set_structure(structure)
    io.save(pdb_file)

    return pdb_file


############################################
############################################
## MAIN FUNCTION
############################################
############################################

def main(args=None):
    args = parse_args(args)

    # Name output PDB file name
    pdb_file =  args.PDB_OUT
    if not pdb_file:
        pdb_file = args.MMCIF_IN.rsplit(".", 1)[0] + ".pdb"

    pdb_file = mmcif_to_pdb(args.MMCIF_IN, pdb_file)
    print(f"Converted {args.MMCIF_IN} to {pdb_file}")


if __name__ == "__main__":
    main()
