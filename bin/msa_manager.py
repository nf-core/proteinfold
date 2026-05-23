#!/usr/bin/env python3
import os
import string
import argparse
import json
import yaml

MAX_MSA_SEQS = 16384
MAX_PAIRED_SEQS = 8192
ID_CHARS = list(string.ascii_uppercase) + list(string.ascii_lowercase) + [str(x) for x in range(10)]


def normalize_id(entity_id):
    if isinstance(entity_id, list):
        normalized = [str(x).strip() for x in entity_id]
        if len(normalized) == 1:
            return normalized[0]
        return ("_multi_", tuple(sorted(normalized)))
    if entity_id is None:
        return None
    return str(entity_id).strip()


def make_entity_key(seq_type, entity_id):
    return (str(seq_type).strip().lower(), normalize_id(entity_id))


def parse_yaml_id_text(raw_id):
    raw = str(raw_id).strip()
    if raw.startswith("[") and raw.endswith("]"):
        vals = [x.strip() for x in raw[1:-1].split(",") if x.strip()]
        if len(vals) == 1:
            return vals[0]
        return vals
    return raw


def parse_template_order(template_yaml):
    order, _ = parse_template_yaml(template_yaml)
    return order


def parse_template_entities(template_yaml):
    _, entities = parse_template_yaml(template_yaml)
    return entities


def parse_template_yaml(template_yaml):
    order = []
    entities = {}
    with open(template_yaml, "r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}

    for seq_item in data.get("sequences", []):
        if not isinstance(seq_item, dict) or len(seq_item) != 1:
            continue
        seq_type, seq_details = next(iter(seq_item.items()))
        if not isinstance(seq_details, dict):
            continue

        seq_id = seq_details.get("id")
        key = make_entity_key(seq_type, seq_id)
        order.append(key)

        payload_key = None
        payload_value = None
        if "sequence" in seq_details:
            payload_key = "sequence"
            payload_value = seq_details.get("sequence")
        elif "smiles" in seq_details:
            payload_key = "smiles"
            payload_value = seq_details.get("smiles")
        elif "ccd" in seq_details:
            payload_key = "ccd"
            payload_value = seq_details.get("ccd")

        if payload_key is not None:
            entities[key] = {
                "id": seq_id,
                "seq_type": seq_type,
                "seq_yaml_label": payload_key,
                "seq_value": payload_value
            }

    return order, entities


def format_yaml_id(seq_id):
    if isinstance(seq_id, list):
        if len(seq_id) == 1:
            return seq_id[0]
        return f"[ {', '.join([str(x) for x in seq_id])} ]"
    return seq_id


def get_entry_payload(seq_type, seq_details):
    seq_type_norm = str(seq_type).strip().lower()
    if seq_type_norm in ["protein", "rna", "dna"]:
        return str(seq_details.get("sequence", "")).strip()
    if seq_type_norm == "ligand":
        if "smiles" in seq_details:
            return str(seq_details.get("smiles", "")).strip()
        if "ccdCodes" in seq_details:
            codes = seq_details.get("ccdCodes", [])
            if isinstance(codes, list):
                return " ".join([str(x).strip() for x in codes]).strip()
            return str(codes).strip()
        if "ccd" in seq_details:
            return str(seq_details.get("ccd", "")).strip()
    return ""


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


def parse_msa(msa_path, output_dir, meta_id):
    os.makedirs(output_dir, exist_ok=True)
    homolog = ""
    section_index = 0

    with open(msa_path, "r") as file:
        first_line = file.readline()
        if not first_line.startswith("#"):
            homologs_lengths = [len(file.readline().strip('\n'))]
            sequence_groups = [[[],[]]]
            is_multimer = False
        else:
            homologs_lengths = [int(x.strip()) for x in first_line.replace('#',"").split()[0].split(",")]
            sequence_groups = [[[], []] for _ in range(len(homologs_lengths))]
            is_multimer = True

    with open(msa_path, "r") as file:
        if is_multimer:
            file.readline()
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
        filename = os.path.join(output_dir, f"{meta_id}_{seq_index}.csv")
        with open(filename, "w") as out_file:
            out_file.write("key,sequence\n")
            if len(homologs_lengths)==1: #Homo-oligomer: all sequences are paired
                paired_sequences = sequence_groups[seq_index][0]+sequence_groups[seq_index][1]
                for i, seq in enumerate(paired_sequences):
                    out_file.write(f"{i},{seq}\n")
            else:
                paired_sequences = sequence_groups[seq_index][0]
                for i, seq in enumerate(paired_sequences, start=1):
                    out_file.write(f"{i},{seq}\n")

                unpaired_sequences = sequence_groups[seq_index][1]
                for seq in unpaired_sequences:
                    out_file.write(f"-1,{seq}\n")

def parse_msa_json(msa_path, output_dir, meta_id, template_yaml=None):
    os.makedirs(output_dir, exist_ok=True)
    with open(msa_path, "r") as file:
        msa_data = json.load(file)

    parsed_entries = []
    entry_map = {}
    for seq_info in msa_data['sequences']:
        for seq_type, seq_details in seq_info.items():
            seq_id = seq_details.get('id')
            key = make_entity_key(seq_type, seq_id)
            entry = {
                "seq_type": seq_type,
                "seq_details": seq_details,
                "payload": get_entry_payload(seq_type, seq_details)
            }
            parsed_entries.append(entry)
            if key is not None and key not in entry_map:
                entry_map[key] = entry

    ordered_entries = []
    ordered_template_keys = []
    used_keys = set()
    template_entities = {}
    if template_yaml:
        template_order, template_entities = parse_template_yaml(template_yaml)
        for key in template_order:
            if key in entry_map:
                ordered_entries.append(entry_map[key])
                ordered_template_keys.append(key)
                used_keys.add(key)
                continue

            # Fallback: MMseqs may reshuffle/swap ids; match by type + sequence payload
            if key in template_entities:
                template_type = str(template_entities[key]["seq_type"]).strip().lower()
                template_payload = str(template_entities[key]["seq_value"]).strip()
                for entry in parsed_entries:
                    entry_key = make_entity_key(entry["seq_type"], entry["seq_details"].get("id"))
                    if entry_key in used_keys:
                        continue
                    entry_type = str(entry["seq_type"]).strip().lower()
                    if entry_type == template_type and entry["payload"] == template_payload:
                        ordered_entries.append(entry)
                        ordered_template_keys.append(key)
                        used_keys.add(entry_key)
                        break
    for entry in parsed_entries:
        key = make_entity_key(entry["seq_type"], entry["seq_details"].get("id"))
        if key not in used_keys:
            ordered_entries.append(entry)
            ordered_template_keys.append(None)
            used_keys.add(key)

    filename = os.path.join(output_dir, f"{meta_id}.yaml")
    with open(filename, "w") as out_file:
        out_file.write("version: 1\nsequences:")
        for idx, entry in enumerate(ordered_entries):
            seq_type = entry["seq_type"]
            seq_details = entry["seq_details"]
            seq_key = make_entity_key(seq_type, seq_details.get("id"))
            template_key = ordered_template_keys[idx]

            seq_label = "sequence"
            seq_yaml_label = "sequence"
            if seq_type == "ligand":
                if "ccdCodes" in seq_details.keys():
                    seq_label = "ccdCodes"
                    seq_details["ccdCodes"] = " ".join(seq_details["ccdCodes"])
                    seq_yaml_label = "ccd"
                elif "smiles" in seq_details.keys():
                    seq_label = "smiles"
                    seq_yaml_label = "smiles"

            seq_value = seq_details[seq_label]
            templ = None
            if template_key in template_entities:
                templ = template_entities[template_key]
            elif seq_key in template_entities:
                templ = template_entities[seq_key]

            if templ is not None:
                seq_type = templ["seq_type"]
                seq_yaml_label = templ["seq_yaml_label"]
                seq_value = templ["seq_value"]

            yaml_id_source = seq_details.get("id")
            if templ is not None:
                yaml_id_source = templ["id"]
            yaml_id = format_yaml_id(yaml_id_source)
            out_file.write(f"\n  - {seq_type}:\n      id: {yaml_id}\n      {seq_yaml_label}: {seq_value}")
            if seq_type == "protein":
                if "pairedMsa" not in seq_details or "unpairedMsa" not in seq_details:
                    raise ValueError(
                        f"Protein entity '{yaml_id}' is missing pairedMsa/unpairedMsa in MMseqs JSON"
                    )
                # Keep MSA numbering aligned with entity order in YAML so non-protein
                # entities (e.g. RNA/ligands) preserve index gaps, matching server mode.
                msa_idx = idx
                out_file.write(f"\n      msa: {meta_id}_{msa_idx}.csv")

                with open(os.path.join(output_dir, f"{meta_id}_{msa_idx}.csv"), "w") as msa_out_file:
                    msa_out_file.write("key,sequence\n")
                    for seq in ['pairedMsa', 'unpairedMsa']:
                        lines = seq_details[seq].splitlines()[1::2]
                        final_seqs = "\n".join(f"{i + 1 if seq == 'pairedMsa' else -1},{x}" for i, x in enumerate(lines))
                        if len(final_seqs) > 0:
                            msa_out_file.write(final_seqs)
                            msa_out_file.write("\n")

def main():
    parser = argparse.ArgumentParser(description="Split multi-A3M file into CSV sequences per section.")
    parser.add_argument("msa_path", help="Path to input .a3m file")
    parser.add_argument("-o", "--output_dir", default="output_msa", help="Directory to write output CSVs")
    parser.add_argument("--meta_id", default="default", help="Prefix for MSA files")
    parser.add_argument("--template_yaml", default=None, help="Optional original Boltz YAML for entity order")

    args = parser.parse_args()
    parse_msa_json(args.msa_path, args.output_dir, args.meta_id, args.template_yaml)


if __name__ == "__main__":
    main()
