#!/usr/bin/env python

# This script is based on the example at: https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv

import sys
import argparse
import pandas as pd
import numpy as np


def parse_args(args=None):
    Description = "Check content of nf-core/proteinfold tcrdock samplesheet file and split into batches."

    parser = argparse.ArgumentParser(description=Description)
    parser.add_argument("FILE_IN", help="Input samplesheet file.")
    parser.add_argument("BATCH_SIZE", help="Amount of targets to run in one process. Model will only be compiled once per process (~5x time consumption for first target), however multiple processes can be parallelized.")
    return parser.parse_args(args)

def parse_samplesheet(file_in, batch_size):
    """
    This function checks that the samplesheet follows the following structure:
    organism, mhc_class, mhc, peptide, va, ja, cdr3a, vb, jb, cdr3b
    mouse|human, 1|2, MHC allele (e.g. A*02:01 or H2Db), peptide sequence (for MHC class 2 exactly 9 core residues + 1 residue on either side), V-alpha gene, J-alpha gene, CDR3-alpha sequence (starts with C, ends with the F/W/etc right before the GXG sequence in the J gene), V-beta gene, J-beta gene, CDR3-beta sequence (starts with C, ends with the F/W/etc right before the GXG sequence in the J gene)
    Only checks if correct columns are present and no value is missing.

    It also converts the CSV to TSV format and splits the samplesheet using batch_size.
    """
    # Read CSV
    df = pd.read_csv(file_in)

    # Check header
    HEADER = ["organism", "mhc_class", "mhc", "peptide", "va", "ja", "cdr3a", "vb", "jb", "cdr3b"]
    header = df.columns.to_list()
    if header[: len(HEADER)] != HEADER:
        print("ERROR: Please check samplesheet header -> {} != {}".format("\t".join(header), "\t".join(HEADER)))
        sys.exit(1)

    # Check that all values exist
    if (df.isna().sum().sum() > 0):
        print("ERROR: Please check samplesheet -> NaN values present.")
        sys.exit(1)

    # Split dataframe into batches
    for i, batch in enumerate(split_dataframe(df, batch_size)):
        batch.to_csv(f'samplesheet_batch{i}.tsv', sep="\t", index=False)


def split_dataframe(df, batch_size):
    # Calculate the number of batches
    num_batches = int(np.ceil(len(df) / batch_size))

    # Split the dataframe into batches
    batches = np.array_split(df, num_batches)

    return batches


def main(args=None):
    args = parse_args(args)
    parse_samplesheet(args.FILE_IN, int(args.BATCH_SIZE))


if __name__ == "__main__":
    sys.exit(main())
