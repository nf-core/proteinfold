#!/usr/bin/env python3

import sys
import argparse
import json
import string

def parse_args(args=None):
    """
    Parse command line arguments for the script.

    Required arguments:
        FILE_IN: Input fasta file path
        ID: Identifier for the protein sequence (will be used in output filename and JSON)

    Optional arguments:
        -ms/--model_seed: AlphaFold3 model seed(s) to use (default: [11])
    """
    Description = "Convert fasta files to Alphafold3 json format."
    Epilog = "Example usage: python fasta_to_alphafold3_json.py <FILE_IN> <ID>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)

    ## REQUIRED PARAMETERS
    parser.add_argument(
        "FILE_IN",
        help="Input fasta file."
    )
    parser.add_argument(
        "ID",
        help="ID for file name and for json id tag."
    )

    ## OPTIONAL PARAMETERS
    parser.add_argument(
        "-ms",
        "--model_seed",
        type=int,
        nargs='+',
        dest="MODEL_SEED",
        default=[11],
        help="Alphafold 3 model seed."
    )

    return parser.parse_args(args)

def sanitised_name(id):
    """
    Sanitize the input ID to create a valid filename.

    This function is copied from AlphaFold3 source code to ensure consistent naming:
    https://github.com/google-deepmind/alphafold3/blob/7fdf96161d61a6e18048e5c62bf7e1d711992943/src/alphafold3/common/folding_input.py#L1166-L1170
    It converts the ID to lowercase, replaces spaces with underscores, and removes
    any characters that aren't allowed in filenames.

    Args:
        id (str): Input identifier

    Returns:
        str: Sanitized version of the ID suitable for use as a filename
    """
    lower_spaceless_name = id.lower().replace(' ', '_')
    allowed_chars = set(string.ascii_lowercase + string.digits + '_-.')
    return ''.join(l for l in lower_spaceless_name if l in allowed_chars)

def fasta_to_alphafold3_json(file_in, id):
    """
    Convert a single-sequence FASTA file to AlphaFold3 JSON format.

    This function reads a FASTA file and converts it to the format required by AlphaFold3.
    It only processes single-sequence FASTA files and raises an error for multi-sequence files.

    The function expects a samplesheet.csv with the following format:
        id,fasta
        T1024,path/to/T1024.fasta
        T1026,path/to/T1026.fasta

    Args:
        file_in (str): Path to input FASTA file
        id (str): Identifier for the sequence

    Returns:
        dict: Dictionary containing the sequence information in AlphaFold3 format

    Raises:
        RuntimeError: If the input file contains multiple sequences
    """
    sequence_list = []
    sequence = None
    fasta_mapping_dict = {}

    with open(file_in, "r", encoding="utf-8-sig") as fin:
        n_seq = 0
        for l in fin:
            l = l.strip()
            if l.startswith(">"):
                if n_seq > 1:
                    raise RuntimeError("Multifasta files are not allowed")
                n_seq += 1
                if sequence:
                    sequence_list.append(sequence)
                sequence = {"id": id, "sequence": ""}
            else:
                sequence["sequence"] += l

    return sequence

def create_json_dict(sequence, model_seed):
    """
    Create the final JSON dictionary in AlphaFold3 format.

    The function creates a JSON structure that follows AlphaFold3's requirements:
    {
        "name": "sequence_id",
        "sequences": [
            {
                "protein": {
                    "id": "A",
                    "sequence": "protein_sequence"
                }
            }
        ],
        "modelSeeds": [seed_values],
        "dialect": "alphafold3",
        "version": 1
    }

    Args:
        sequence (dict): Dictionary containing sequence information
        model_seed (list): List of model seeds to use

    Returns:
        dict: JSON-compatible dictionary in AlphaFold3 format
    """
    json_sequence_dict = {}

    item = {
        "name": f"{sequence['id']}",
        "sequences": [
            {
                "protein": {
                    "id": "A",
                    "sequence": sequence["sequence"]
                }
            },
        ],
        "modelSeeds": model_seed,
        "dialect": "alphafold3",
        "version": 1
    }

    json_sequence_dict[sequence["id"]] = item

    return json_sequence_dict

def main(args=None):
    """
    Main function to process FASTA files and create AlphaFold3 JSON files.

    The script:
    1. Parses command line arguments
    2. Sanitizes the input ID for filename use
    3. Reads and processes the FASTA file
    4. Creates the JSON structure
    5. Writes the output to a JSON file

    The output filename will be the sanitized ID with .json extension.
    """
    args = parse_args(args)
    id = args.ID

    if id.endswith(".json"):
        id = id[:-5]
        reformatted_id = sanitised_name(id)
    else:
        reformatted_id = sanitised_name(id)

    out_json = f"{reformatted_id}.json"

    sequence = fasta_to_alphafold3_json(args.FILE_IN, reformatted_id)
    json_dict = create_json_dict(sequence, args.MODEL_SEED)

    print ("json file " + out_json)
    with open(out_json, "w") as fout:
        json.dump(json_dict[reformatted_id], fout, indent=4)

    with open(out_json, 'r') as f:
        json_str = f.read()

if __name__ == "__main__":
    sys.exit(main())
