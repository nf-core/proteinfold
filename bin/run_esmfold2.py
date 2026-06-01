#!/usr/bin/env python3

import argparse
import os
from pathlib import Path

from Bio import PDB


def parse_args(args=None):
    description = "Run local ESMFold2 inference from a FASTA file and local or remote weights."
    epilog = (
        "Example usage: python run_esmfold2.py "
        "--fasta input.fasta --output_dir . --id sample1 --weights biohub/ESMFold2-Fast"
    )

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--fasta",
        "--input",
        required=True,
        help="Input FASTA file containing exactly one protein sequence.",
    )
    parser.add_argument(
        "-w",
        "--weights",
        "--model",
        default="biohub/ESMFold2-Fast",
        help=(
            "Local Hugging Face-style ESMFold2 weights directory or model ID. "
            "Default: biohub/ESMFold2-Fast"
        ),
    )
    parser.add_argument(
        "--chain-id",
        default="A",
        help="Chain identifier to use in the structure input. Default: A",
    )
    parser.add_argument(
        "--id",
        "--name",
        "--prefix",
        dest="output_prefix",
        default="",
        help=(
            "Sample identifier used to derive default output names. "
            "Defaults to a sanitized FASTA stem."
        ),
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
        "--cif-out",
        default="",
        help="Explicit output mmCIF path. Overrides the derived mmCIF path if provided.",
    )
    parser.add_argument(
        "--pdb-out",
        default="",
        help="Explicit output PDB path converted from the mmCIF prediction.",
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


def read_single_sequence_fasta(fasta_path: Path) -> str:
    """Read a single protein sequence from FASTA."""

    sequences = []
    current = []

    for line in fasta_path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith(">"):
            if current:
                sequences.append("".join(current))
                current = []
            continue
        current.append(line)

    if current:
        sequences.append("".join(current))

    if not sequences:
        raise ValueError(f"No sequence found in FASTA file: {fasta_path}")
    if len(sequences) != 1:
        raise ValueError(
            f"Expected exactly one sequence in FASTA file, found {len(sequences)}: {fasta_path}"
        )

    return sequences[0].upper()


def resolve_device(device: str, torch_module) -> str:
    """Resolve the requested inference device."""

    if device == "auto":
        return "cuda" if torch_module.cuda.is_available() else "cpu"
    if device == "cuda" and not torch_module.cuda.is_available():
        raise RuntimeError("CUDA was requested but no GPU is available.")
    return device


def mmcif_to_pdb(mmcif_file: Path, pdb_file: Path) -> None:
    """Convert an mmCIF file to PDB format."""

    parser = PDB.MMCIFParser(QUIET=True)
    structure = parser.get_structure("structure", str(mmcif_file))

    io = PDB.PDBIO()
    io.set_structure(structure)
    io.save(str(pdb_file))


def resolve_output_paths(args, fasta_path: Path) -> tuple[str, Path, Path | None]:
    """Resolve output prefix and structure output paths."""

    output_dir = Path(args.output_dir)
    output_prefix = args.output_prefix or sanitised_name(fasta_path.stem)

    cif_out = Path(args.cif_out) if args.cif_out else output_dir / f"{output_prefix}_esmfold2.cif"

    if args.pdb_out:
        pdb_out = Path(args.pdb_out)
    elif args.output_format in {"pdb", "both"}:
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


def main(args=None):
    args = parse_args(args)
    cache_path = configure_model_cache(args.cache_dir)
    import torch
    from esm.models.esmfold2 import (
        ESMFold2InputBuilder,
        ProteinInput,
        StructurePredictionInput,
    )
    from transformers.models.esmfold2.modeling_esmfold2 import ESMFold2Model

    fasta_path = Path(args.fasta).expanduser().resolve()
    weights_ref = args.weights
    output_prefix, cif_out, pdb_out = resolve_output_paths(args, fasta_path)

    sequence = read_single_sequence_fasta(fasta_path)
    device = resolve_device(args.device, torch)

    torch.manual_seed(args.seed)
    if device == "cuda":
        torch.cuda.manual_seed_all(args.seed)

    model = ESMFold2Model.from_pretrained(str(weights_ref)).to(device).eval()
    spi = StructurePredictionInput(
        sequences=[ProteinInput(id=args.chain_id, sequence=sequence)]
    )

    result = ESMFold2InputBuilder().fold(
        model,
        spi,
        num_loops=args.num_loops,
        num_sampling_steps=args.num_sampling_steps,
        num_diffusion_samples=args.num_diffusion_samples,
        seed=args.seed,
    )

    cif_out.parent.mkdir(parents=True, exist_ok=True)
    cif_out.write_text(result.complex.to_mmcif())

    if pdb_out:
        pdb_out.parent.mkdir(parents=True, exist_ok=True)
        mmcif_to_pdb(cif_out, pdb_out)

    print(f"name={output_prefix}")
    print(f"fasta={fasta_path}")
    print(f"weights={weights_ref}")
    if cache_path:
        print(f"hf_cache={cache_path}")
    print(f"saved_mmcif={cif_out}")
    if pdb_out:
        print(f"saved_pdb={pdb_out}")
    print(f"device={device}")
    print(f"plddt_mean={float(result.plddt.mean()):.3f}")
    print(f"ptm={float(result.ptm):.3f}")
    print(f"iptm={float(result.iptm):.3f}")


if __name__ == "__main__":
    main()
