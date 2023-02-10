#!/usr/bin/env python

# TODO nf-core: Update the script to check the samplesheet
# This script is based on the example at: https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv

import os
import sys
import errno
import argparse


def parse_args(args=None):
    Description = "Reformat nf-core/proteinfold samplesheet file and check its contents."
    Epilog = "Example usage: python check_samplesheet.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input samplesheet file.")
    parser.add_argument("FILE_OUT", help="Output file.")
    return parser.parse_args(args)


def make_dir(path):
    if len(path) > 0:
        try:
            os.makedirs(path)
        except OSError as exception:
            if exception.errno != errno.EEXIST:
                raise exception


def print_error(error, context="Line", context_str=""):
    error_str = "ERROR: Please check samplesheet -> {}".format(error)
    if context != "" and context_str != "":
        error_str = "ERROR: Please check samplesheet -> {}\n{}: '{}'".format(
            error, context.strip(), context_str.strip()
        )
    print(error_str)
    sys.exit(1)


# TODO nf-core: Update the check_samplesheet function
def check_samplesheet(file_in, file_out):
    """
    This function checks that the samplesheet follows the following structure:
    sequence,fasta
    T1024,T1024.fasta
    For an example see:
    https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv
    """
    sequence_mapping_dict = {}
    with open(file_in, "r") as fin:
        ## Check header
        MIN_COLS = 2
        # TODO nf-core: Update the column names for the input samplesheet
        HEADER = ["sequence", "fasta"]
        header = [x.strip('"') for x in fin.readline().strip().split(",")]
        if header[: len(HEADER)] != HEADER:
            print("ERROR: Please check samplesheet header -> {} != {}".format(",".join(header), ",".join(HEADER)))
            sys.exit(1)

        ## Check sample entries
        for line in fin:
            lspl = [x.strip().strip('"') for x in line.strip().split(",")]

            # Check valid number of columns per row
            if len(lspl) < len(HEADER):
                print_error(
                    "Invalid number of columns (minimum = {})!".format(len(HEADER)),
                    "Line",
                    line,
                )
            num_cols = len([x for x in lspl if x])
            if num_cols < MIN_COLS:
                print_error(
                    "Invalid number of populated columns (minimum = {})!".format(MIN_COLS),
                    "Line",
                    line,
                )

            ## Check sequence name entries
            sequence, fasta = lspl[: len(HEADER)]
            sequence = sequence.replace(" ", "_")
            if not sequence:
                print_error("Sequence entry has not been specified!", "Line", line)

                ## Check fasta file extension
                # for fastq in [fastq_1, fastq_2]:
                if fasta:
                    if fasta.find(" ") != -1:
                        print_error("fasta file contains spaces!", "Line", line)
                    if not fasta.endswith(".fasta") and not fastq.endswith(".fa"):
                        print_error(
                            "Fasta file does not have extension '.fasta' or '.fa'!",
                            "Line",
                            line,
                        )

            sequence_info = []  ## [fasta]
            if sequence and fasta:
                sequence_info = [fasta]
            else:
                print_error("Invalid combination of columns provided!", "Line", line)

            ## Create sequence mapping dictionary = { sequence: [fasta] }
            if sequence not in sequence_mapping_dict:
                sequence_mapping_dict[sequence] = [sequence_info]
            else:
                if sequence_info in sequence_mapping_dict[sequence]:
                    print_error("Samplesheet contains duplicate rows!", "Line", line)
                else:
                    sequence_mapping_dict[sequence].append(sequence_info)

    ## Write validated samplesheet with appropriate columns
    if len(sequence_mapping_dict) > 0:
        out_dir = os.path.dirname(file_out)
        make_dir(out_dir)
        with open(file_out, "w") as fout:
            fout.write(",".join(["sequence", "fasta"]) + "\n")
            for sequence in sorted(sequence_mapping_dict.keys()):
                ## Check that multiple runs of the same sample are of the same datatype
                if not all(x[0] == sequence_mapping_dict[sequence][0][0] for x in sequence_mapping_dict[sequence]):
                    print_error(
                        "Multiple runs of a sequence must be of the same datatype!", "Sequence: {}".format(sequence)
                    )
                for idx, val in enumerate(sequence_mapping_dict[sequence]):
                    fout.write(",".join(["{}_T{}".format(sequence, idx + 1)] + val) + "\n")
    else:
        print_error("No entries to process!", "Samplesheet: {}".format(file_in))


def main(args=None):
    args = parse_args(args)
    check_samplesheet(args.FILE_IN, args.FILE_OUT)


if __name__ == "__main__":
    sys.exit(main())
