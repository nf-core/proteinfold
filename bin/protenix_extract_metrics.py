#!/usr/bin/env python3
import argparse
import csv
import glob
import json
import os
import sys
import numpy as np

def write_tsv(file_path, rows):
    """기존 스크립트와 동일한 방식으로 TSV 작성"""
    with open(file_path, 'w', newline='') as out_f:
        writer = csv.writer(out_f, delimiter='\t')
        writer.writerows(rows)

def format_pae_rows(pae_data):
    """PAE 데이터를 4소수점 문자열로 변환"""
    if not pae_data:
        return [["0.0000"]]
    return [[f"{num:.4f}" for num in row] for row in pae_data]

def extract_metrics(name, out_dir):
    """
    Protenix 출력 폴더에서 데이터를 추출하여 
    기존 nf-core/proteinfold 호환 포맷으로 저장
    """
    # 1. Protenix JSON 파일 찾기
    json_files = sorted(
        glob.glob(os.path.join(out_dir, "**", "*_summary_confidence_sample_*.json"), recursive=True)
    )

    if not json_files:
        print(f"Warning: No Protenix confidence files found in {out_dir}", file=sys.stderr)
        return

    ptm_data = {}
    iptm_data = {}
    plddt_summary = []
    pae_created = False

    for idx, json_file in enumerate(json_files):
        with open(json_file, 'r') as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                continue

        model_id = idx # rank_0, rank_1... 형식을 위해 숫자로 관리

        # pLDDT 추출 (Protenix는 숫자 하나이므로 리스트로 변환하여 저장)
        if "plddt" in data:
            val = data["plddt"]
            plddt_summary.append([f"rank_{idx}", f"{val:.2f}"])

        # PAE 추출 (있을 경우에만 생성, 없을 경우 나중에 dummy 생성)
        if "pae" in data and data["pae"]:
            write_tsv(f"{name}_{idx}_pae.tsv", format_pae_rows(data["pae"]))
            pae_created = True

        # pTM / iPTM 추출
        if 'ptm' in data and data['ptm'] is not None:
            ptm_data[model_id] = f"{np.round(data['ptm'], 3)}"
        if 'iptm' in data and data['iptm'] is not None:
            iptm_data[model_id] = f"{np.round(data['iptm'], 3)}"

    # --- Nextflow Output Emission을 위한 파일 생성 보장 ---

    # 1. pLDDT (MultiQC용)
    if plddt_summary:
        # 기존 스타일: [["Model", "pLDDT"], ["rank_0", "82.07"]]
        write_tsv(f"{name}_plddt.tsv", [["Positions", "pLDDT"]] + plddt_summary)
    else:
        write_tsv(f"{name}_plddt.tsv", [["Positions", "pLDDT"]])

    # 2. pTM & iPTM (기존 스크립트 정렬 방식 유지)
    if ptm_data:
        ptm_rows = sorted([[k, v] for k, v in ptm_data.items()], key=lambda x: x[0])
        write_tsv(f"{name}_ptm.tsv", ptm_rows)
    
    if iptm_data:
        iptm_rows = sorted([[k, v] for k, v in iptm_data.items()], key=lambda x: x[0])
        write_tsv(f"{name}_iptm.tsv", iptm_rows)

    # 3. PAE (데이터가 없어도 0번 파일은 있어야 에러 안남)
    if not pae_created:
        write_tsv(f"{name}_0_pae.tsv", [["0.0000"]])

    # 4. Chainwise pTM/iPTM (Protenix 특화 데이터)
    try:
        with open(json_files[0], 'r') as f:
            data = json.load(f)
        
        c_iptm, c_ptm = [], []
        if "chain_pair_iptm" in data and isinstance(data["chain_pair_iptm"], list):
            matrix = np.array(data["chain_pair_iptm"])
            for i in range(matrix.shape[0]):
                for j in range(matrix.shape[1]):
                    val = f"{matrix[i][j]:.4f}"
                    if i != j: c_iptm.append(val)
                    else: c_ptm.append(val)
        
        # 데이터가 없어도 무조건 파일 생성 (Nextflow 요구사항)
        write_tsv(f"{name}_chainwise_ptm.tsv", [c_ptm] if c_ptm else [["0.0000"]])
        write_tsv(f"{name}_chainwise_iptm.tsv", [c_iptm] if c_iptm else [["0.0000"]])
    except:
        write_tsv(f"{name}_chainwise_ptm.tsv", [["0.0000"]])
        write_tsv(f"{name}_chainwise_iptm.tsv", [["0.0000"]])

def main():
    parser = argparse.ArgumentParser(description="Extract metrics from Protenix output")
    parser.add_argument("--name", required=True, help="Sample identifier (meta.id)")
    parser.add_argument("--out_dir", required=True, help="Protenix output directory")
    args = parser.parse_args()
    
    extract_metrics(args.name, args.out_dir)

if __name__ == "__main__":
    main()
