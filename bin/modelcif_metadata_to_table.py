#!/usr/bin/env python3
"""Export the descriptive metadata in a modelCIF file as a TSV table."""
import argparse
import csv
import sys

import modelcif.reader


def _value(value):
    if value is None:
        return ""
    if isinstance(value, (list, tuple, set)):
        return ", ".join(_value(item) for item in value)
    return str(value)


def _rows(system):
    yield "system", "title", _value(getattr(system, "title", None))
    yield "system", "entities", str(len(getattr(system, "entities", [])))
    yield "system", "asym_units", str(len(getattr(system, "asym_units", [])))
    yield "system", "model_groups", str(len(getattr(system, "model_groups", [])))
    for index, software in enumerate(getattr(system, "software", []), 1):
        prefix = f"software[{index}]"
        for field in ("name", "version", "classification", "description", "location"):
            yield prefix, field, _value(getattr(software, field, None))
    for index, protocol in enumerate(getattr(system, "protocols", []), 1):
        prefix = f"protocol[{index}]"
        yield prefix, "steps", str(len(getattr(protocol, "steps", [])))
        for step_index, step in enumerate(getattr(protocol, "steps", []), 1):
            step_prefix = f"{prefix}.step[{step_index}]"
            yield step_prefix, "type", type(step).__name__
            for field in ("name", "details"):
                yield step_prefix, field, _value(getattr(step, field, None))
    for index, group in enumerate(getattr(system, "model_groups", []), 1):
        prefix = f"model_group[{index}]"
        yield prefix, "name", _value(getattr(group, "name", None))
        yield prefix, "models", str(len(getattr(group, "models", [])))


def write_metadata(input_path, output_handle):
    mode = "rb" if input_path.lower().endswith(".bcif") else "r"
    with open(input_path, mode) as handle:
        systems = modelcif.reader.read(handle)
    if not systems:
        raise ValueError(f"No ModelCIF data blocks found in {input_path}")
    writer = csv.writer(output_handle, delimiter="\\t", lineterminator="\\n")
    writer.writerow(("system", "section", "field", "value"))
    for system_index, system in enumerate(systems, 1):
        for section, field, value in _rows(system):
            writer.writerow((system_index, section, field, value))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input modelCIF (.cif, .mmcif, or .bcif) file")
    parser.add_argument("-o", "--output", help="Output TSV path (default: stdout)")
    args = parser.parse_args(argv)
    if args.output:
        with open(args.output, "w", newline="") as output_handle:
            write_metadata(args.input, output_handle)
    else:
        write_metadata(args.input, sys.stdout)


if __name__ == "__main__":
    main()
