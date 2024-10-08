#!/usr/bin/env python
import pickle
import os
import argparse


def read_pkl(id, pkl_files):
    for pkl_file in pkl_files:
        dict_data = pickle.load(open(pkl_file, "rb"))
        if pkl_file.endswith("features.pkl"):
            with open(f"{id}_msa.tsv", "w") as out_f:
                for val in dict_data["msa"]:
                    out_f.write("\t".join([str(x) for x in val]) + "\n")
        else:
            model_id = (
                os.path.basename(pkl_file)
                .replace("result_model_", "")
                .replace("_pred_0.pkl", "")
            )
            with open(f"{id}_lddt_{model_id}.tsv", "w") as out_f:
                out_f.write("\t".join([str(x) for x in dict_data["plddt"]]) + "\n")


parser = argparse.ArgumentParser()
parser.add_argument("--pkls", dest="pkls", required=True, nargs="+")
parser.add_argument("--name", dest="name")
parser.add_argument("--output_dir", dest="output_dir")
parser.set_defaults(output_dir="")
parser.set_defaults(name="")
args = parser.parse_args()

read_pkl(args.name, args.pkls)
