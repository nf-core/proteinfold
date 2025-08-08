#!/usr/bin/env python3
import os
import string
import argparse


MAX_MSA_SEQS = 16384
MAX_PAIRED_SEQS = 8192
ID_CHARS = list(string.ascii_uppercase) + list(string.ascii_lowercase) + [str(x) for x in range(10)]


def get_sub_sequences(seq_lengths, whole_seq):
    out_seqs = []
    curr_seq = ""
    curr_seq_itr = 0
    total_letters = 0
    for letter in whole_seq:
        curr_seq += letter
        if letter.isupper() or letter == "-":
            total_letters += 1
        if total_letters == seq_lengths[curr_seq_itr]:
            out_seqs.append(curr_seq)
            curr_seq = ""
            curr_seq_itr += 1
            total_letters = 0

    if len(out_seqs) != len(seq_lengths):
        print("Something wrong in the input file, could not generate the required number of sequences")
        exit(1)

    return out_seqs


def parse_msa(msa_path, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    homolog = ""
    section_index = 0

    with open(msa_path, "r") as file:
        first_line = file.readline()
        if not first_line.startswith("#"):
            print("Error: File might not have multiple A3M sections.")
            return

        homologs_lengths = [int(x.strip()) for x in first_line.replace("#", "").split()[0].split(",")]
        sequence_groups = [[[], []] for _ in range(len(homologs_lengths))]

        header_line = file.readline().strip()[1:]
        expected_section_headers = [x.strip() for x in header_line.split()]
        current_header = header_line
        first_seq = False
        for line in file:
            line = line.strip()
            if line.startswith(">"):
                if homolog:
                    if first_seq and section_index > 0:
                        first_seq = False
                    else:
                        sub_sequences = get_sub_sequences(homologs_lengths, homolog)
                        for seq_index in range(len(homologs_lengths)):
                            if section_index == 0:
                                if len(sequence_groups[seq_index][0]) < MAX_PAIRED_SEQS:
                                    sequence_groups[seq_index][0].append(sub_sequences[seq_index])
                            else:
                                if seq_index == section_index - 1:
                                    if len(sequence_groups[seq_index][1]) + len(sequence_groups[seq_index][0]) < MAX_MSA_SEQS:
                                        sequence_groups[seq_index][1].append(sub_sequences[seq_index])

                homolog = ""
                current_header = line[1:].strip()

                if section_index < len(homologs_lengths) and current_header == expected_section_headers[section_index]:
                    section_index += 1
                    first_seq = True
            else:
                homolog += line
        if homolog:
            if first_seq and section_index > 0:
                first_seq = False
            else:
                sub_sequences = get_sub_sequences(homologs_lengths, homolog)
                for seq_index in range(len(homologs_lengths)):
                    if section_index == 0:
                        if len(sequence_groups[seq_index][0]) < MAX_PAIRED_SEQS:
                            sequence_groups[seq_index][0].append(sub_sequences[seq_index])
                    else:
                        if seq_index == section_index - 1:
                            if len(sequence_groups[seq_index][1]) + len(sequence_groups[seq_index][0]) < MAX_MSA_SEQS:
                                sequence_groups[seq_index][1].append(sub_sequences[seq_index])

    for seq_index in range(len(homologs_lengths)):
        filename = os.path.join(output_dir, f"{ID_CHARS[seq_index]}.csv")
        with open(filename, "w") as out_file:
            out_file.write("key,sequence\n")
            paired_sequences = sequence_groups[seq_index][0]
            for i, seq in enumerate(paired_sequences, start=1):
                out_file.write(f"{i},{seq}\n")

            unpaired_sequences = sequence_groups[seq_index][1]
            for seq in unpaired_sequences:
                out_file.write(f"-1,{seq}\n")


def main():
    parser = argparse.ArgumentParser(description="Split multi-A3M file into CSV sequences per section.")
    parser.add_argument("msa_path", help="Path to input .a3m file")
    parser.add_argument("-o", "--output_dir", default="output_msa", help="Directory to write output CSVs")

    args = parser.parse_args()
    parse_msa(args.msa_path, args.output_dir)


if __name__ == "__main__":
    main()
