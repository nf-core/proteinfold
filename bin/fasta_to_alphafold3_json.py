#!/usr/bin/env python3

import sys
import argparse
import json
import string
import re
from Bio import SeqIO

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

def infer_entity_type(header, sequence):
    ENTITY_TYPES = ["protein", "ccd", "smiles", "dna", "rna"]

    header_lower = header.lower()

    for entity in ENTITY_TYPES:
        if entity in header_lower:
            return entity
    seq = sequence.strip()
    seq_set = set(seq)
    # RNA: only A,C,U,G,N
    if len(seq_set - set("ACUGN")) == 0:
        return "rna"
    # DNA: only A,C,T,G,N
    if len(seq_set - set("ACTGN")) == 0:
        return "dna"
    # Protein: only 20 AA, not just A,C,T,G,U,N
    protein_letters = set("ACDEFGHIKLMNPQRSTVWY")
    if len(seq_set - protein_letters) == 0 and not (seq_set <= set("ACUGTN")):
        return "protein"
    # SMILES: fallback
    if re.fullmatch(r"[A-Za-z0-9@+\\-\\[\\]\\(\\)=#\\\$%]+", seq):
        return "smiles"
    return "unknown"

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

def fasta_to_alphafold3_json(file_in):
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
    VALID_CHAIN_IDS = list(string.ascii_uppercase) + list(string.ascii_lowercase) + [str(x) for x in range(0, 10)]
    entities = []

    for i, record in enumerate(SeqIO.parse(file_in, "fasta")):
        sequence = record.seq._data.decode()
        header = record.description
        entity_type = infer_entity_type(header, sequence)
        entities.append((entity_type, VALID_CHAIN_IDS[i], sequence))

    return entities

def create_json_dict(id, entities, model_seed):
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

    json_sequence_list = []

    for entity in entities:
        item = {
            entity[0]: {
                "id": entity[1],
                "sequence": entity[2]
            }
        }

        json_sequence_list.append(item)


    alphafold3_json_dict = {
        "name": f"{id}",
        "sequences": json_sequence_list,
        "modelSeeds": model_seed,
        "dialect": "alphafold3",
        "version": 1
    }

    return alphafold3_json_dict

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

    entities = fasta_to_alphafold3_json(args.FILE_IN)
    json_dict = create_json_dict(reformatted_id, entities, args.MODEL_SEED)

    print ("json file " + out_json)
    with open(out_json, "w") as fout:
        json.dump(json_dict, fout, indent=4)

    with open(out_json, 'r') as f:
        json_str = f.read()

if __name__ == "__main__":
    sys.exit(main())
