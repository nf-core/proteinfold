#!/usr/bin/env python3

import sys
import argparse
import json
import copy


def parse_args(args=None):
    """
    Parse command line arguments for the script.

    Required arguments:
        FASTA: Input fasta file path
        ID: Identifier for the protein sequence (will be used in output filename)
    """
    Description = "Convert fasta files to HelixFold3 json format."
    Epilog = "Example usage: python fasta_to_json.py <FASTA> <ID>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)

    ## REQUIRED PARAMETERS
    parser.add_argument(
        "FASTA",
        help="Input fasta file."
    )
    parser.add_argument(
        "ID",
        help="ID for file name."
    )

    return parser.parse_args(args)


def fasta_to_json(file_in):
    """
    Convert a FASTA file to a list of entities in HelixFold3 JSON format.

    Args:
        file_in (str): Path to the input FASTA file

    Returns:
        dict: Dictionary with entities list
    """
    seq_template = {
        "type": "",
        "sequence": "",
        "count": 1
    }
    final_res = {"entities": []}
    seq_type = "protein"
    fasta_data = ""

    with open(file_in, "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if line.startswith(">"):
            if len(fasta_data) > 0:
                new_entry = copy.deepcopy(seq_template)
                new_entry["type"] = seq_type
                new_entry["sequence"] = fasta_data
                final_res["entities"].append(new_entry)
            fasta_data = ""
        else:
            fasta_data += f"{line}"

    if len(fasta_data) > 0:
        new_entry = copy.deepcopy(seq_template)
        new_entry["type"] = seq_type
        new_entry["sequence"] = fasta_data
        final_res["entities"].append(new_entry)

    return final_res


def main(args=None):
    """
    Main function to process FASTA files and create HelixFold3 JSON files.
    """
    args = parse_args(args)
    id = args.ID
    out_json = f"{id}.json"

    json_dict = fasta_to_json(args.FASTA)

    with open(out_json, "w") as json_file:
        json.dump(json_dict, json_file, indent=4, sort_keys=True)


if __name__ == "__main__":
    sys.exit(main())
