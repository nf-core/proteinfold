#!/usr/bin/env python3

import argparse
import csv
import inspect
import os
import string
from pathlib import Path

from Bio import PDB
import yaml


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
        "--output_format",
        choices=["cif", "pdb", "both"],
        default="cif",
        help=(
            "Output structure format when explicit output paths are not provided. "
            "Default: cif"
        ),
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
        "--num-recycles",
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
        "--model_seed",
        type=int,
        dest="seed",
        default=0,
        help="Random seed. Default: 0",
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


def _class_or_none(module, *names):
    for name in names:
        cls = getattr(module, name, None)
        if cls is not None:
            return cls
    return None


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
    msa_cls = _class_or_none(esmfold2_module, "MSA")
    if msa_cls is None:
        try:
            from esm.data import MSA as esm_data_msa_cls
            msa_cls = esm_data_msa_cls
        except Exception:
            msa_cls = None
    if msa_cls is None:
        raise RuntimeError(
            "MSA was requested in YAML, but no MSA class was found in the installed esm package"
        )

    if not hasattr(msa_cls, "from_a3m"):
        raise RuntimeError("MSA class does not provide from_a3m(path=..., ...) method")

    return msa_cls.from_a3m(path=str(msa_path), remove_insertions=True, max_sequences=1000)


def build_spi_from_boltz_yaml(yaml_path: Path, esmfold2_module):
    data = yaml.safe_load(yaml_path.read_text()) or {}
    sequences = data.get("sequences")
    if not isinstance(sequences, list) or len(sequences) == 0:
        raise ValueError("Boltz YAML must contain a non-empty 'sequences' list")

    ProteinInput = _class_or_none(esmfold2_module, "ProteinInput")
    DNAInput = _class_or_none(esmfold2_module, "DNAInput", "DnaInput")
    RNAInput = _class_or_none(esmfold2_module, "RNAInput", "RnaInput")
    LigandInput = _class_or_none(esmfold2_module, "LigandInput")
    StructurePredictionInput = _class_or_none(esmfold2_module, "StructurePredictionInput")

    if StructurePredictionInput is None or ProteinInput is None:
        raise RuntimeError("Could not import required ESMFold2 input classes")

    spi_sequences = []
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

            if seq_type == "protein":
                input_cls = ProteinInput
            elif seq_type == "rna":
                if RNAInput is None:
                    raise RuntimeError("RNAInput/RnaInput class not available in installed esm package")
                input_cls = RNAInput
            else:
                if DNAInput is None:
                    raise RuntimeError("DNAInput/DnaInput class not available in installed esm package")
                input_cls = DNAInput

            msa = None
            if seq_type == "protein":
                msa_path_value = details.get("msa")
                if msa_path_value is not None and str(msa_path_value).strip():
                    msa_path = _resolve_input_path(str(msa_path_value).strip(), yaml_path)
                    if not msa_path.exists():
                        raise FileNotFoundError(f"MSA file does not exist: {msa_path}")
                    msa = _build_msa_from_path(msa_path, esmfold2_module)

            for entity_id in entity_ids:
                spi_sequences.append(
                    _construct_input_object(
                        input_cls,
                        id=entity_id,
                        sequence=sequence,
                        msa=msa,
                    )
                )
            continue

        # ligand
        if LigandInput is None:
            raise RuntimeError("LigandInput class not available in installed esm package")
        smiles = details.get("smiles")
        ccd = _parse_ligand_ccd(details)
        if not smiles and not ccd:
            raise ValueError("Ligand entry must contain one of: smiles, ccd, ccdCodes")
        if smiles is not None:
            smiles = str(smiles).strip()
        for entity_id in entity_ids:
            spi_sequences.append(_construct_input_object(LigandInput, id=entity_id, smiles=smiles, ccd=ccd))

    return StructurePredictionInput(sequences=spi_sequences)


def resolve_device(device: str, torch_module) -> str:
    """Resolve the requested inference device."""

    if device == "auto":
        return "cuda" if torch_module.cuda.is_available() else "cpu"
    if device == "cuda" and not torch_module.cuda.is_available():
        raise RuntimeError("CUDA was requested but no GPU is available.")
    return device


def mmcif_to_pdb(mmcif_file: Path, pdb_file: Path) -> None:
    """Convert an mmCIF file to PDB format."""

    def ensure_atom_site_occupancy(path: Path) -> None:
        lines = path.read_text().splitlines()
        i = 0
        changed = False

        while i < len(lines):
            if lines[i].strip() != "loop_":
                i += 1
                continue

            tag_start = i + 1
            tag_end = tag_start
            while tag_end < len(lines) and lines[tag_end].lstrip().startswith("_"):
                tag_end += 1
            tags = lines[tag_start:tag_end]

            atom_site_tags = [t.strip() for t in tags if t.strip().startswith("_atom_site.")]
            if not atom_site_tags:
                i = tag_end
                continue
            if "_atom_site.occupancy" in atom_site_tags:
                i = tag_end
                continue

            # Add missing tag and fill each atom_site row with occupancy=1.00.
            lines.insert(tag_end, "_atom_site.occupancy")
            row_idx = tag_end + 1
            while row_idx < len(lines):
                row = lines[row_idx]
                row_stripped = row.strip()
                if not row_stripped:
                    row_idx += 1
                    continue
                if row_stripped == "#" or row_stripped == "loop_" or row_stripped.startswith("_"):
                    break
                lines[row_idx] = f"{row} 1.00"
                row_idx += 1
            changed = True
            i = row_idx

        if changed:
            path.write_text("\n".join(lines) + "\n")

    ensure_atom_site_occupancy(mmcif_file)
    parser = PDB.MMCIFParser(QUIET=True)
    structure = parser.get_structure("structure", str(mmcif_file))

    io = PDB.PDBIO()
    io.set_structure(structure)
    io.save(str(pdb_file))


def resolve_output_paths(args, input_path: Path) -> tuple[str, Path, Path | None]:
    """Resolve output prefix and structure output paths."""

    output_dir = Path(args.output_dir)
    output_prefix = args.output_prefix or sanitised_name(input_path.stem)

    cif_out = output_dir / f"{output_prefix}_esmfold2.cif"

    if args.output_format in {"pdb", "both"}:
        pdb_out = output_dir / f"{output_prefix}_esmfold2.pdb"
    else:
        pdb_out = None

    return output_prefix, cif_out, pdb_out


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


def main(args=None):
    args = parse_args(args)
    cache_path = configure_model_cache(args.cache_dir)
    import torch
    from esm.models import esmfold2 as esmfold2_module
    from esm.models.esmfold2 import ESMFold2InputBuilder
    from transformers.models.esmfold2.modeling_esmfold2 import ESMFold2Model

    input_path = Path(args.input).expanduser().resolve()
    output_prefix, cif_out, pdb_out = resolve_output_paths(args, input_path)
    device = resolve_device(args.device, torch)

    torch.manual_seed(args.seed)
    if device == "cuda":
        torch.cuda.manual_seed_all(args.seed)

    model = ESMFold2Model.from_pretrained("biohub/ESMFold2", local_files_only=True).to(device).eval()

    input_suffixes = {s.lower() for s in input_path.suffixes}
    if ".yaml" not in input_suffixes and ".yml" not in input_suffixes:
        raise ValueError(f"Input must be a Boltz YAML file (.yaml/.yml), got: {input_path}")
    spi = build_spi_from_boltz_yaml(input_path, esmfold2_module)

    result = ESMFold2InputBuilder().fold(
        model,
        spi,
        num_loops=args.num_loops,
        num_sampling_steps=args.num_sampling_steps,
        num_diffusion_samples=args.num_diffusion_samples,
        seed=args.seed,
    )

    #print(result)

    pae = result.pae.cpu().numpy()
    pae_tsv_out = Path(args.output_dir) / f"{output_prefix}_0_pae.tsv"
    write_pae_tsv(pae, pae_tsv_out)
    ptm_tsv_out = Path(args.output_dir) / f"{output_prefix}_ptm.tsv"
    iptm_tsv_out = Path(args.output_dir) / f"{output_prefix}_iptm.tsv"
    write_scalar_metric_tsv(result.ptm, ptm_tsv_out)
    write_scalar_metric_tsv(result.iptm, iptm_tsv_out)
    chainwise_iptm_tsv_out = Path(args.output_dir) / f"{output_prefix}_chainwise_iptm.tsv"
    write_chainwise_iptm_tsv(getattr(result, "pair_chains_iptm", None), chainwise_iptm_tsv_out)

    cif_out.parent.mkdir(parents=True, exist_ok=True)
    cif_out.write_text(result.complex.to_mmcif())

    if pdb_out:
        pdb_out.parent.mkdir(parents=True, exist_ok=True)
        mmcif_to_pdb(cif_out, pdb_out)

    print(f"name={output_prefix}")
    print(f"input={input_path}")
    #if cache_path:
    #    print(f"hf_cache={cache_path}")
    print(f"saved_mmcif={cif_out}")
    if pdb_out:
        print(f"saved_pdb={pdb_out}")
    print(f"saved_pae_tsv={pae_tsv_out}")
    print(f"saved_ptm_tsv={ptm_tsv_out}")
    print(f"saved_iptm_tsv={iptm_tsv_out}")
    print(f"saved_chainwise_iptm_tsv={chainwise_iptm_tsv_out}")
    print(f"device={device}")
    print(f"plddt_mean={float(result.plddt.mean()):.3f}")
    print(f"ptm={float(result.ptm):.3f}")
    print(f"iptm={float(result.iptm):.3f}")


if __name__ == "__main__":
    main()
