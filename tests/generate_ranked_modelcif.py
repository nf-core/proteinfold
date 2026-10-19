#!/usr/bin/env python3
"""Derive small, distinct ranked test structures from the rank 0 fixture."""

import sys
from decimal import Decimal
from pathlib import Path


OFFSETS = {
    1: ("-0.050", "0.035", "-0.015"),
    2: ("-0.005", "0.040", "-0.030"),
    3: ("-0.030", "-0.005", "0.020"),
    4: ("0.005", "0.005", "-0.025"),
}


def main(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    lines = source.read_text().splitlines(keepends=True)
    for rank, offsets in OFFSETS.items():
        output = []
        for line in lines:
            if line.startswith("ATOM "):
                fields = line.split()
                for column, offset in zip((10, 11, 12), offsets):
                    fields[column] = f"{Decimal(fields[column]) + Decimal(offset):.3f}"
                line = " ".join(fields) + "\n"
            else:
                line = line.replace("DUMMY_MMCIF_rank_0", f"DUMMY_MMCIF_rank_{rank}")
            output.append(line)
        (destination / f"DUMMY_MMCIF_rank_{rank}.mmcif").write_text("".join(output))


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
