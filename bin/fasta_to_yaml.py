#!/usr/bin/env python3

import os
import sys
import argparse
import string


def parse_args(args=None):
    """
    Parse command line arguments for the script.

    Required arguments:
        FASTA: Input fasta file path
        ID: Identifier for the protein sequence (will be used in output filename and YAML job_name)
    """
    Description = "Convert fasta files to RoseTTAFold-All-Atom yaml format."
    Epilog = "Example usage: python fasta_to_yaml.py <FASTA> <ID>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)

    ## REQUIRED PARAMETERS
    parser.add_argument(
        "FASTA",
        help="Input fasta file."
    )
    parser.add_argument(
        "ID",
        help="ID for file name and YAML job_name."
    )

    return parser.parse_args(args)


def fasta_to_yaml(file_in, id):
    """
    Convert a FASTA file to a RoseTTAFold-All-Atom YAML config and individual chain FASTA files.

    Creates:
        - Individual chain FASTA files in out_fasta/ directory

    Returns:
        str: YAML configuration string for RFAA

    Args:
        file_in (str): Path to the input FASTA file
        id (str): Identifier for the job name in the YAML config
    """
    all_combinations = list(string.ascii_uppercase) + list(string.ascii_lowercase) + [str(x) for x in range(0, 10)]
    yaml_template = f"defaults:\n - base\njob_name: \"{id}\"\nprotein_inputs:\n"
    counter = 0
    fasta_data = ""
    os.makedirs("out_fasta", exist_ok=True)

    with open(file_in, "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if line.startswith(">"):
            if len(fasta_data) > 0:
                with open(f"out_fasta/{all_combinations[counter]}.fasta", "w") as fasta_file:
                    fasta_file.write(fasta_data + "\n")
                yaml_template += f" {all_combinations[counter]}:\n  fasta_file: {all_combinations[counter]}.fasta\n"
                counter += 1
            fasta_data = f"{line}\n"
        else:
            fasta_data += f"{line}"

    if len(fasta_data) > 0:
        with open(f"out_fasta/{all_combinations[counter]}.fasta", "w") as fasta_file:
            fasta_file.write(fasta_data + "\n")
        yaml_template += f" {all_combinations[counter]}:\n  fasta_file: {all_combinations[counter]}.fasta\n"

    return yaml_template


def main(args=None):
    """
    Main function to process FASTA files and create RoseTTAFold-All-Atom YAML files.
    """
    args = parse_args(args)
    id = args.ID
    out_yaml = f"{id}.yaml"

    yaml_content = fasta_to_yaml(args.FASTA, id)

    with open(out_yaml, "w") as yaml_file:
        yaml_file.write(yaml_content)


if __name__ == "__main__":
    sys.exit(main())
