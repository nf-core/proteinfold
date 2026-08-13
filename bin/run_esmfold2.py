#!/usr/bin/env python3

import argparse
import csv
import inspect
import math
import os
import re
import string
from pathlib import Path

from Bio import PDB
import yaml


AA_TO_INT = {
    "A": 0, "C": 1, "D": 2, "E": 3, "F": 4, "G": 5, "H": 6, "I": 7, "K": 8, "L": 9,
    "M": 10, "N": 11, "P": 12, "Q": 13, "R": 14, "S": 15, "T": 16, "V": 17, "W": 18, "Y": 19,
    ".": 20, "-": 21,
}

PAIRED_KEY_RE = re.compile(r"\bkey=(\d+)\b")


def parse_args(args=None):
    description = "Run local ESMFold2 inference from a Boltz YAML file."
    epilog = (
        "Example usage: python run_esmfold2.py "
        "--input input.yaml --output_dir . --id sample1"
    )

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input",
        required=True,
        help="Input Boltz YAML file.",
    )
    parser.add_argument(
        "--id",
        "--name",
        "--prefix",
        dest="output_prefix",
        default="",
        help=("Sample identifier used to derive default output names. Defaults to a sanitized input stem."),
    )
    parser.add_argument(
        "-o",
        "--output_dir",
        default=".",
        help="Output directory for derived structure file paths. Default: current directory",
    )
    parser.add_argument(
        "--cache-dir",
        default="",
        help=(
            "Optional Hugging Face cache directory for model downloads. "
            "Sets both HF_HOME and TRANSFORMERS_CACHE."
        ),
    )
    parser.add_argument(
        "--device",
        default="auto",
        choices=["auto", "cuda", "cpu"],
        help="Inference device. Default: auto",
    )
    parser.add_argument(
        "--num-loops",
        type=int,
        dest="num_loops",
        default=3,
        help="Number of recycling loops. Default: 3",
    )
    parser.add_argument(
        "--num-sampling-steps",
        type=int,
        default=50,
        help="Number of diffusion sampling steps. Default: 50",
    )
    parser.add_argument(
        "--num-diffusion-samples",
        type=int,
        default=1,
        help="Number of diffusion samples. Default: 1",
    )
    parser.add_argument(
        "--seed",
        type=int,
        dest="seed",
        default=0,
        help="Initial random seed. Default: 0",
    )
    parser.add_argument(
        "--num-seeds",
        type=int,
        default=1,
        help="Number of sequential seeds to evaluate starting from --seed. Default: 1",
    )
    return parser.parse_args(args)


def sanitised_name(name: str) -> str:
    """Create a filesystem-friendly sample identifier."""

    lower_spaceless_name = name.lower().replace(" ", "_")
    allowed_chars = set("abcdefghijklmnopqrstuvwxyz0123456789_-." )
    sanitized = "".join(char for char in lower_spaceless_name if char in allowed_chars)
    return sanitized or "esmfold2"


def _ensure_list_ids(entity_id) -> list[str]:
    if isinstance(entity_id, list):
        return [str(x).strip() for x in entity_id if str(x).strip()]
    if entity_id is None:
        raise ValueError("Entity is missing required 'id' field")
    raw_id = str(entity_id).strip()
    if raw_id.startswith("[") and raw_id.endswith("]"):
        parsed = [x.strip() for x in raw_id[1:-1].split(",") if x.strip()]
        if parsed:
            return parsed
    return [raw_id]


def _normalize_seq_type(seq_type: str) -> str:
    seq_type = str(seq_type).strip().lower()
    if seq_type in {"protein", "rna", "dna", "ligand"}:
        return seq_type
    raise ValueError(f"Unsupported Boltz entity type '{seq_type}'")


def _construct_input_object(input_cls, **kwargs):
    accepted = set(inspect.signature(input_cls).parameters)
    safe_kwargs = {k: v for k, v in kwargs.items() if k in accepted and v is not None}
    return input_cls(**safe_kwargs)


def _normalize_modification_entry(entry: dict, seq_type: str) -> tuple[int, str]:
    if not isinstance(entry, dict):
        raise ValueError(f"Each '{seq_type}' modification entry must be a mapping")

    position = entry.get("position")
    ccd = entry.get("ccd")

    if position is None:
        raise ValueError(f"Each '{seq_type}' modification entry must include 'position'")
    if ccd is None or not str(ccd).strip():
        raise ValueError(f"Each '{seq_type}' modification entry must include non-empty 'ccd'")

    try:
        normalized_position = int(position)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"Invalid modification position for '{seq_type}': {position!r}"
        ) from exc

    return normalized_position, str(ccd).strip()


def _build_modifications(details: dict, seq_type: str, esmfold2_module) -> list | None:
    raw_modifications = details.get("modifications")
    if raw_modifications is None:
        return None
    if not isinstance(raw_modifications, list):
        raise ValueError(f"'{seq_type}' modifications must be provided as a list")
    if len(raw_modifications) == 0:
        return []

    modification_cls = esmfold2_module.Modification
    accepted = set(inspect.signature(modification_cls).parameters)
    modifications = []
    for entry in raw_modifications:
        position, ccd = _normalize_modification_entry(entry, seq_type)
        modification_kwargs = {}
        if "position" in accepted:
            modification_kwargs["position"] = position
        if "ccd" in accepted:
            modification_kwargs["ccd"] = ccd

        if "position" not in modification_kwargs or "ccd" not in modification_kwargs:
            raise RuntimeError(
                "Installed esm Modification class does not accept expected 'position' and 'ccd' fields"
            )

        modifications.append(modification_cls(**modification_kwargs))

    return modifications


def _parse_ligand_ccd(details: dict) -> list[str] | None:
    if "ccdCodes" in details and details["ccdCodes"] is not None:
        raw = details["ccdCodes"]
        if isinstance(raw, list):
            values = [str(x).strip() for x in raw if str(x).strip()]
            return values or None
        text = str(raw).strip()
        return [text] if text else None
    if "ccd" in details and details["ccd"] is not None:
        text = str(details["ccd"]).strip()
        if not text:
            return None
        # msa_manager.py may serialize as whitespace-separated CCD tokens.
        return [x for x in text.split() if x]
    return None


def _resolve_input_path(path_text: str, yaml_path: Path) -> Path:
    path = Path(path_text).expanduser()
    if not path.is_absolute():
        path = (yaml_path.parent / path).resolve()
    return path


def _build_msa_from_path(msa_path: Path, esmfold2_module):
    msa_cls = esmfold2_module.MSA
    return msa_cls.from_a3m(path=str(msa_path), remove_insertions=True, max_sequences=1000)


def _a3m_sequence_to_int_row(sequence: str) -> list[str]:
    filtered = "".join(char for char in sequence.strip() if not char.islower())
    return [str(AA_TO_INT.get(char.upper(), 20)) for char in filtered]


def _parse_a3m_entries(msa_path: Path) -> list[tuple[str, str]]:
    entries = []
    header = None
    sequence_chunks = []

    with msa_path.open() as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if header is not None:
                    entries.append((header, "".join(sequence_chunks)))
                header = line
                sequence_chunks = []
                continue
            if header is None:
                continue
            sequence_chunks.append(line)

    if header is not None:
        entries.append((header, "".join(sequence_chunks)))

    return entries


def _parse_chain_msa_rows(msa_path: Path) -> tuple[dict[int, list[str]], list[list[str]]]:
    paired_rows = {}
    unpaired_rows = []

    for header, sequence in _parse_a3m_entries(msa_path):
        int_row = _a3m_sequence_to_int_row(sequence)
        match = PAIRED_KEY_RE.search(header)
        if match is None:
            unpaired_rows.append(int_row)
            continue
        paired_rows[int(match.group(1))] = int_row

    return paired_rows, unpaired_rows


def _build_msa_tsv_rows(chain_msas: list[dict]) -> list[list[str]]:
    if not chain_msas:
        return []

    paired_key_sets = [set(chain["paired_rows"]) for chain in chain_msas if chain["paired_rows"]]
    common_paired_keys = sorted(set.intersection(*paired_key_sets), key=int) if paired_key_sets else []

    final_rows = []
    for pair_key in common_paired_keys:
        row = []
        for chain in chain_msas:
            row.extend(chain["paired_rows"][pair_key])
        final_rows.append(row)

    unpaired_rows_by_chain = []
    for chain in chain_msas:
        leftover_paired_rows = [
            row for pair_key, row in sorted(chain["paired_rows"].items())
            if pair_key not in common_paired_keys
        ]
        chain_unpaired_rows = leftover_paired_rows + chain["unpaired_rows"]
        unpaired_rows_by_chain.append(chain_unpaired_rows)

    msa_widths = []
    for chain, chain_rows in zip(chain_msas, unpaired_rows_by_chain):
        if chain_rows:
            msa_widths.append(len(chain_rows[0]))
        else:
            msa_widths.append(chain["width"])

    row_offsets = []
    total_rows = 0
    for chain_rows in unpaired_rows_by_chain:
        next_total = total_rows + len(chain_rows)
        row_offsets.append((total_rows, next_total))
        total_rows = next_total

    for row_idx in range(total_rows):
        row = []
        for chain_rows, width, (minrow, maxrow) in zip(unpaired_rows_by_chain, msa_widths, row_offsets):
            if minrow <= row_idx < maxrow:
                row.extend(chain_rows[row_idx - minrow])
            else:
                row.extend(["21"] * width)
        final_rows.append(row)

    return final_rows


def build_spi_from_boltz_yaml(yaml_path: Path, esmfold2_module):
    data = yaml.safe_load(yaml_path.read_text()) or {}
    sequences = data.get("sequences")
    if not isinstance(sequences, list) or len(sequences) == 0:
        raise ValueError("Boltz YAML must contain a non-empty 'sequences' list")

    ProteinInput = esmfold2_module.ProteinInput
    DNAInput = esmfold2_module.DNAInput
    RNAInput = esmfold2_module.RNAInput
    LigandInput = esmfold2_module.LigandInput
    StructurePredictionInput = esmfold2_module.StructurePredictionInput

    spi_sequences = []
    chain_msas = []
    for seq_item in sequences:
        if not isinstance(seq_item, dict) or len(seq_item) != 1:
            raise ValueError("Each Boltz YAML sequence entry must be a one-key mapping")

        seq_type_raw, details = next(iter(seq_item.items()))
        seq_type = _normalize_seq_type(seq_type_raw)
        if not isinstance(details, dict):
            raise ValueError(f"Invalid '{seq_type}' entry; expected mapping")

        entity_ids = _ensure_list_ids(details.get("id"))

        if seq_type in {"protein", "rna", "dna"}:
            sequence = str(details.get("sequence", "")).strip().upper()
            if not sequence:
                raise ValueError(f"'{seq_type}' entity is missing required 'sequence'")
            modifications = _build_modifications(details, seq_type, esmfold2_module)

            if seq_type == "protein":
                input_cls = ProteinInput
            elif seq_type == "rna":
                input_cls = RNAInput
            else:
                input_cls = DNAInput

            msa = None
            if seq_type == "protein":
                msa_path_value = details.get("msa")
                if msa_path_value is not None and str(msa_path_value).strip():
                    msa_path = _resolve_input_path(str(msa_path_value).strip(), yaml_path)
                    if not msa_path.exists():
                        raise FileNotFoundError(f"MSA file does not exist: {msa_path}")
                    msa = _build_msa_from_path(msa_path, esmfold2_module)
                    paired_rows, unpaired_rows = _parse_chain_msa_rows(msa_path)
                    chain_width = 0
                    if paired_rows:
                        chain_width = len(next(iter(paired_rows.values())))
                    elif unpaired_rows:
                        chain_width = len(unpaired_rows[0])
                    for _ in entity_ids:
                        chain_msas.append(
                            {
                                "paired_rows": dict(paired_rows),
                                "unpaired_rows": list(unpaired_rows),
                                "width": chain_width,
                            }
                        )

            for entity_id in entity_ids:
                spi_sequences.append(
                    _construct_input_object(
                        input_cls,
                        id=entity_id,
                        sequence=sequence,
                        msa=msa,
                        modifications=modifications,
                    )
                )
            continue

        # ligand
        smiles = details.get("smiles")
        ccd = _parse_ligand_ccd(details)
        if not smiles and not ccd:
            raise ValueError("Ligand entry must contain one of: smiles, ccd, ccdCodes")
        if smiles is not None:
            smiles = str(smiles).strip()
        for entity_id in entity_ids:
            spi_sequences.append(_construct_input_object(LigandInput, id=entity_id, smiles=smiles, ccd=ccd))

    return StructurePredictionInput(sequences=spi_sequences), _build_msa_tsv_rows(chain_msas)


def resolve_device(device: str, torch_module) -> str:
    """Resolve the requested inference device."""

    if device == "auto":
        return "cuda" if torch_module.cuda.is_available() else "cpu"
    if device == "cuda" and not torch_module.cuda.is_available():
        raise RuntimeError("CUDA was requested but no GPU is available.")
    return device


def resolve_output_paths(args, input_path: Path) -> tuple[str, Path]:
    """Resolve output prefix and structure output path."""

    output_dir = Path(args.output_dir)
    output_prefix = args.output_prefix or sanitised_name(input_path.stem)

    cif_out = output_dir / f"{output_prefix}_esmfold2.cif"

    return output_prefix, cif_out


def configure_model_cache(cache_dir: str) -> Path | None:
    """Configure Hugging Face cache paths for the current process."""

    if not cache_dir:
        return None

    cache_path = Path(cache_dir).expanduser().resolve()
    cache_path.mkdir(parents=True, exist_ok=True)
    os.environ["HF_HOME"] = str(cache_path)
    os.environ["TRANSFORMERS_CACHE"] = str(cache_path / "transformers")
    return cache_path


def write_pae_tsv(pae_matrix, output_path: Path) -> None:
    """Write PAE values in extract_metrics.py-compatible TSV format."""

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerows([[f"{num:.4f}" for num in row] for row in pae_matrix])


def write_scalar_metric_tsv(metric_value: float, output_path: Path) -> None:
    """Write scalar metric in extract_metrics.py-compatible TSV format."""

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow([0, f"{float(metric_value):.3f}"])


def write_msa_tsv(msa_rows: list[list[str]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerows(msa_rows)


def _idx_to_letter(idx: int) -> str:
    """Convert numeric index to chain-like letters: 0->A, 25->Z, 26->AA."""

    result = ""
    while idx >= 0:
        result = string.ascii_uppercase[idx % 26] + result
        idx = idx // 26 - 1
        if idx < 0:
            break
    return result


def write_chainwise_iptm_tsv(pair_chains_iptm, output_path: Path) -> None:
    """Write chainwise iPTM in extract_metrics.py-compatible TSV format."""

    output_path.parent.mkdir(parents=True, exist_ok=True)

    if pair_chains_iptm is None:
        output_path.touch()
        return

    # Support both tensor/array outputs and dict-style outputs.
    if hasattr(pair_chains_iptm, "detach"):
        chain_iptm_matrix = pair_chains_iptm.detach().cpu().tolist()
    elif hasattr(pair_chains_iptm, "tolist"):
        chain_iptm_matrix = pair_chains_iptm.tolist()
    elif isinstance(pair_chains_iptm, dict):
        row_keys = sorted(pair_chains_iptm.keys(), key=int)
        col_keys = sorted(next(iter(pair_chains_iptm.values())).keys(), key=int)
        chain_iptm_matrix = [
            [float(pair_chains_iptm[row][col]) for col in col_keys]
            for row in row_keys
        ]
    else:
        raise TypeError(f"Unsupported pair_chains_iptm type: {type(pair_chains_iptm)}")

    pair_entries = []
    for i, row in enumerate(chain_iptm_matrix):
        for j, value in enumerate(row):
            if i != j:
                pair_entries.append(((i, j), value))

    # Mirror extract_metrics.py format_iptm_rows single-model output.
    iptm_rows = [
        [""] + [f"{_idx_to_letter(idx[0])}:{_idx_to_letter(idx[1])}" for idx, _ in pair_entries],
        [0] + [f"{val:.4f}" for _, val in pair_entries],
    ]
    formatted_rows = [list(row) for row in zip(*iptm_rows)]

    with output_path.open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerows(formatted_rows)


def _metric_to_float(metric_value) -> float | None:
    if metric_value is None:
        return None
    if hasattr(metric_value, "detach"):
        metric_value = metric_value.detach().cpu()
    if hasattr(metric_value, "item"):
        metric_value = metric_value.item()
    try:
        metric_float = float(metric_value)
    except (TypeError, ValueError):
        return None
    if math.isnan(metric_float):
        return None
    return metric_float


def _score_result(result) -> tuple[int, float, str]:
    iptm_score = _metric_to_float(getattr(result, "iptm", None))
    if iptm_score is not None:
        return 1, iptm_score, "iptm"

    ptm_score = _metric_to_float(getattr(result, "ptm", None))
    if ptm_score is not None:
        return 0, ptm_score, "ptm"

    raise RuntimeError("Prediction result is missing both iptm and ptm scores")


def _select_best_result(result):
    if not isinstance(result, list):
        metric_priority, ranking_score, ranking_metric = _score_result(result)
        return {
            "result": result,
            "metric_priority": metric_priority,
            "score": ranking_score,
            "metric": ranking_metric,
        }

    if not result:
        raise RuntimeError("Prediction returned an empty result list")

    best_result = None
    for item in result:
        metric_priority, ranking_score, ranking_metric = _score_result(item)
        candidate = {
            "result": item,
            "metric_priority": metric_priority,
            "score": ranking_score,
            "metric": ranking_metric,
        }
        if best_result is None or (
            candidate["metric_priority"],
            candidate["score"],
        ) > (
            best_result["metric_priority"],
            best_result["score"],
        ):
            best_result = candidate

    return best_result


def _write_optional_scalar_metric_tsv(metric_value, output_path: Path) -> None:
    metric_float = _metric_to_float(metric_value)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if metric_float is None:
        output_path.touch()
        return
    write_scalar_metric_tsv(metric_float, output_path)


def main(args=None):
    args = parse_args(args)
    configure_model_cache(args.cache_dir)
    import torch
    from esm.models import esmfold2 as esmfold2_module
    from esm.models.esmfold2 import ESMFold2InputBuilder
    from transformers.models.esmfold2.modeling_esmfold2 import ESMFold2Model

    input_path = Path(args.input).expanduser().resolve()
    output_prefix, cif_out = resolve_output_paths(args, input_path)
    device = resolve_device(args.device, torch)

    model = ESMFold2Model.from_pretrained("biohub/ESMFold2", local_files_only=True).to(device).eval()
    model.set_kernel_backend("cuequivariance")
    #model = ESMFold2Model.from_pretrained("biohub/ESMFold2").to(device).eval()

    input_suffixes = {s.lower() for s in input_path.suffixes}
    if ".yaml" not in input_suffixes and ".yml" not in input_suffixes:
        raise ValueError(f"Input must be a Boltz YAML file (.yaml/.yml), got: {input_path}")
    spi, msa_rows = build_spi_from_boltz_yaml(input_path, esmfold2_module)

    if args.num_seeds < 1:
        raise ValueError(f"--num-seeds must be at least 1, got: {args.num_seeds}")

    seeds = list(range(int(args.seed), int(args.seed) + int(args.num_seeds)))
    input_builder = ESMFold2InputBuilder()
    best_prediction = None
    for seed in seeds:
        torch.manual_seed(seed)
        if device == "cuda":
            torch.cuda.manual_seed_all(seed)

        result = input_builder.fold(
            model,
            spi,
            num_loops=args.num_loops,
            num_sampling_steps=args.num_sampling_steps,
            num_diffusion_samples=args.num_diffusion_samples,
            seed=seed,
        )
        best_seed_result = _select_best_result(result)
        candidate_prediction = {
            "seed": seed,
            "result": best_seed_result["result"],
            "metric_priority": best_seed_result["metric_priority"],
            "score": best_seed_result["score"],
            "metric": best_seed_result["metric"],
        }
        if best_prediction is None or (
            candidate_prediction["metric_priority"],
            candidate_prediction["score"],
        ) > (
            best_prediction["metric_priority"],
            best_prediction["score"],
        ):
            best_prediction = candidate_prediction

    if best_prediction is None:
        raise RuntimeError("No predictions were produced")

    result = best_prediction["result"]

    #print(result)

    pae = result.pae.cpu().numpy()
    msa_tsv_out = Path(args.output_dir) / f"{output_prefix}_esmfold2_msa.tsv"
    pae_tsv_out = Path(args.output_dir) / f"{output_prefix}_0_pae.tsv"
    if len(msa_rows)>0:
        write_msa_tsv(msa_rows, msa_tsv_out)
    write_pae_tsv(pae, pae_tsv_out)
    ptm_tsv_out = Path(args.output_dir) / f"{output_prefix}_ptm.tsv"
    iptm_tsv_out = Path(args.output_dir) / f"{output_prefix}_iptm.tsv"
    _write_optional_scalar_metric_tsv(getattr(result, "ptm", None), ptm_tsv_out)
    _write_optional_scalar_metric_tsv(getattr(result, "iptm", None), iptm_tsv_out)
    chainwise_iptm_tsv_out = Path(args.output_dir) / f"{output_prefix}_chainwise_iptm.tsv"
    write_chainwise_iptm_tsv(getattr(result, "pair_chains_iptm", None), chainwise_iptm_tsv_out)

    cif_out.parent.mkdir(parents=True, exist_ok=True)
    cif_out.write_text(result.complex.to_mmcif())


    print(f"name={output_prefix}")
    print(f"input={input_path}")
    #if cache_path:
    #    print(f"hf_cache={cache_path}")
    print(f"saved_mmcif={cif_out}")
    print(f"saved_msa_tsv={msa_tsv_out}")
    print(f"saved_pae_tsv={pae_tsv_out}")
    print(f"saved_ptm_tsv={ptm_tsv_out}")
    print(f"saved_iptm_tsv={iptm_tsv_out}")
    print(f"saved_chainwise_iptm_tsv={chainwise_iptm_tsv_out}")
    print(f"device={device}")
    print(f"plddt_mean={float(result.plddt.mean()):.3f}")
    print(f"selected_seed={best_prediction['seed']}")
    print(f"selection_metric={best_prediction['metric']}")
    print(f"selection_score={best_prediction['score']:.3f}")
    print(f"tested_seeds={','.join(str(seed) for seed in seeds)}")
    print(f"ptm={_metric_to_float(getattr(result, 'ptm', None))}")
    print(f"iptm={_metric_to_float(getattr(result, 'iptm', None))}")


if __name__ == "__main__":
    main()
