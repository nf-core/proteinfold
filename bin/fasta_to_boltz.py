#!/usr/bin/env python3

import sys
import os
import argparse
import string
import re


ENTITY_TYPES = ["protein", "ccd", "smiles", "dna", "rna"]


def parse_args(args=None):
    """
    Parse command line arguments for the script.

    Required arguments:
        FASTA: Input fasta file path
        ID: Identifier for the output file
    Optional arguments:
        --msa: MSA files associated with protein sequences
    """
    Description = "Convert fasta files to Boltz format."
    Epilog = "Example usage: python fasta_to_boltz.py <FASTA> <ID> [--msa file1.a3m file2.a3m]"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)

    parser.add_argument(
        "FASTA",
        help="Input fasta file."
    )
    parser.add_argument(
        "ID",
        help="ID for output file name."
    )
    parser.add_argument(
        "--msa",
        nargs='*',
        default=[],
        help="MSA files for protein sequences."
    )

    return parser.parse_args(args)


def infer_entity_type(header, sequence):
    """
    Infer the entity type from the FASTA header and sequence.

    Args:
        header (str): FASTA header line
        sequence (str): Sequence string

    Returns:
        str: Entity type (protein, dna, rna, smiles, ccd, or unknown)
    """
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
    if re.fullmatch(r"[A-Za-z0-9@+\-\[\]\(\)=#\$%]+", seq):
        return "smiles"
    return "unknown"


def fasta_to_boltz(fasta_file, sample_id, msa_files):
    """
    Convert a FASTA file to Boltz format.

    Args:
        fasta_file (str): Path to the input FASTA file
        sample_id (str): Sample identifier for the output file
        msa_files (list): List of MSA file paths for protein sequences
    """
    all_combinations = list(string.ascii_uppercase) + list(string.ascii_lowercase) + [str(x) for x in range(0, 10)]

    os.makedirs("output_fasta", exist_ok=True)
    counter = 0
    msa_counter = 0

    with open(fasta_file, "r") as f:
        lines = f.readlines()

    msa = ""
    fasta_data = ""
    seq_lines = []
    header = None

    unique_proteins = {}
    for line in lines:
        line = line.strip()
        if line.startswith(">"):
            # Write previous entry if exists
            if header is not None:
                sequence = "".join(seq_lines)
                entity_type = infer_entity_type(header, sequence)
                msa = ""
                if entity_type == 'protein':
                    if len(msa_files) > 0:
                        if sequence not in unique_proteins:
                            unique_proteins[sequence] = msa_counter
                            msa_counter += 1
                        this_msa = unique_proteins[sequence]
                        msa = f"|{os.path.basename(msa_files[this_msa])}"
                        if msa[1:] not in msa_files:
                            print(f"Can not find msa file {os.path.basename(msa_files[counter])}")
                            sys.exit(1)
                fasta_data += f">{all_combinations[counter]}|{entity_type}{msa}\n{sequence}\n"
                counter += 1
            header = line
            seq_lines = []
        else:
            seq_lines.append(line)

    # Write last entry
    if header is not None:
        sequence = "".join(seq_lines)
        entity_type = infer_entity_type(header, sequence)
        msa = ""
        if entity_type == 'protein':
            if len(msa_files) > 0:
                if not sequence in unique_proteins:
                    unique_proteins[sequence] = msa_counter
                    msa_counter += 1
                this_msa = unique_proteins[sequence]
                msa = f"|{os.path.basename(msa_files[this_msa])}"
                if msa[1:] not in msa_files:
                    print(f"Can not find msa file {os.path.basename(msa_files[counter])}")
                    sys.exit(1)
        fasta_data += f">{all_combinations[counter]}|{entity_type}{msa}\n{sequence}\n"

    if len(fasta_data) > 0:
        with open(f"output_fasta/{sample_id}.fasta", "w") as outfile:
            outfile.write(fasta_data)


def main(args=None):
    """
    Main function to process FASTA files and create Boltz formatted FASTA files.
    """
    args = parse_args(args)
    fasta_to_boltz(args.FASTA, args.ID, args.msa)


if __name__ == "__main__":
    sys.exit(main())
