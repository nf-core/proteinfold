#!/usr/bin/env python3
"""Create a reviewer-friendly supplementary-information table from ModelCIF."""

import argparse
import csv
import io
import math
import os
import re
import shlex
import statistics
import sys
from collections import defaultdict

import modelcif.reader


SI_COLUMNS = ("Section", "Item", "Result", "Reviewer note")


def _normalize_integer_parameters(text):
    """Normalize integral decimal spellings in integer parameters.

    Some deposited/generated files contain ``integer ... 10.0`` in the
    ``_ma_software_parameter`` loop. Convert that spelling to ``10`` only in
    the in-memory input passed to py-modelcif. The declared integer type and
    source file are preserved.
    """
    lines = text.splitlines(keepends=True)
    in_parameters = False
    saw_parameter_heading = False
    repaired = 0
    row_pattern = re.compile(
        r"^(\s*\S+\s+\S+\s+)(integer(?:-csv)?)(\s+"
        r"(?:'[^']*'|\"[^\"]*\"|\S+)\s+)(\S+)(.*)$"
    )
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("_ma_software_parameter."):
            in_parameters = True
            saw_parameter_heading = True
            continue
        if in_parameters and (
            stripped == "#" or stripped == "loop_" or stripped.startswith("data_")
            or (stripped.startswith("_") and not stripped.startswith("_ma_software_parameter."))
        ):
            in_parameters = False
        if not in_parameters or stripped.startswith("_") or not stripped:
            continue
        match = row_pattern.match(line.rstrip("\r\n"))
        if not match:
            continue
        declared_type, value = match.group(2), match.group(4)
        values = value.split(",") if declared_type == "integer-csv" else [value]
        if values and all(re.fullmatch(r"[-+]?\d+\.0+", item) for item in values):
            normalized = ",".join(item.split(".", 1)[0] for item in values)
            newline = "\n" if line.endswith("\n") else ""
            lines[index] = "".join((match.group(1), declared_type, match.group(3),
                                    normalized, match.group(5), newline))
            repaired += 1
    return "".join(lines), repaired if saw_parameter_heading else 0


def _read_systems(input_path):
    mode = "rb" if input_path.lower().endswith(".bcif") else "r"
    if mode == "rb":
        with open(input_path, mode) as handle:
            return modelcif.reader.read(handle)
    with open(input_path) as handle:
        text = handle.read()
    parameters = _extract_software_parameters(text)
    try:
        systems = modelcif.reader.read(io.StringIO(text))
    except ValueError as error:
        if "invalid literal for int()" not in str(error):
            raise
        repaired_text, repairs = _normalize_integer_parameters(text)
        if not repairs:
            raise
        systems = modelcif.reader.read(io.StringIO(repaired_text))
    for system in systems:
        system._si_file_parameters = parameters
    return systems


def _extract_software_parameters(text):
    """Read parameter name/value pairs independently of CIF category order."""
    lines = iter(text.splitlines())
    parameters = []
    for line in lines:
        if line.strip() != "loop_":
            continue
        headings = []
        data_lines = []
        for loop_line in lines:
            stripped = loop_line.strip()
            if stripped.startswith("_"):
                headings.append(stripped)
            else:
                if stripped:
                    data_lines.append(loop_line)
                break
        if not headings or not all(
            heading.startswith("_ma_software_parameter.") for heading in headings
        ):
            continue
        for loop_line in lines:
            stripped = loop_line.strip()
            if not stripped or stripped == "#" or stripped == "loop_" or stripped.startswith("_"):
                break
            data_lines.append(loop_line)
        columns = [heading.rsplit(".", 1)[-1] for heading in headings]
        try:
            name_index, value_index = columns.index("name"), columns.index("value")
            type_index = columns.index("data_type")
        except ValueError:
            return parameters
        for data_line in data_lines:
            values = shlex.split(data_line, comments=False, posix=True)
            if len(values) > max(name_index, value_index):
                value = values[value_index]
                declared_type = values[type_index]
                if declared_type == "integer" and re.fullmatch(r"[-+]?\d+\.0+", value):
                    value = value.split(".", 1)[0]
                elif declared_type == "integer-csv":
                    parts = value.split(",")
                    if all(re.fullmatch(r"[-+]?\d+\.0+", part) for part in parts):
                        value = ",".join(part.split(".", 1)[0] for part in parts)
                parameters.append(f"{values[name_index]}={value}")
        return parameters
    return parameters


def _value(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "Yes" if value else "No"
    rendered = str(value)
    if rendered in (".", "?"):
        return ""
    return " ".join(rendered.split())


def _sequence(entity):
    sequence = getattr(entity, "sequence", None)
    if sequence is None:
        return ""
    if isinstance(sequence, str):
        return sequence
    letters = []
    for component in sequence:
        letters.append(
            _value(getattr(component, "code_canonical", None))
            or _value(getattr(component, "code", None))
            or "X"
        )
    return "".join(letters)


def _software_members(software):
    if isinstance(software, (list, tuple, set)):
        return list(software)
    members = getattr(software, "software", None)
    if members is None:
        return [software]
    return list(members) if isinstance(members, (list, tuple, set)) else [software]


def _software_label(software):
    labels = []
    for member in _software_members(software):
        base = getattr(member, "software", member)
        name = _value(getattr(base, "name", None))
        version = _value(getattr(base, "version", None))
        label = name + (f" (version {version})" if version else "")
        if label and label not in labels:
            labels.append(label)
    return "; ".join(labels)


def _parameters(software):
    parameters = []
    for member in _software_members(software):
        for parameter in getattr(member, "parameters", []) or []:
            name = _value(getattr(parameter, "name", None)) or "parameter"
            value = _value(getattr(parameter, "value", None))
            pair = f"{name}={value}"
            if pair not in parameters:
                parameters.append(pair)
    return parameters


def _metric_name(metric):
    return (_value(getattr(metric, "name", None))
            or _value(getattr(metric, "metric_name", None))
            or type(metric).__name__)


def _metric_value(metric):
    for field in ("value", "metric_value"):
        value = getattr(metric, field, None)
        if isinstance(value, (int, float)) and math.isfinite(value):
            return float(value)
    return None


def _metric_mode(metric):
    return (_value(getattr(metric, "mode", None)) or type(metric).__name__).lower()


def _format_number(value):
    return f"{value:.3f}".rstrip("0").rstrip(".")


def _residue_chain_id(residue):
    asym = (getattr(residue, "asym", None)
            or getattr(residue, "asym_unit", None))
    return _value(getattr(asym, "id", None))


def _feature_chain_ids(feature):
    """Return chain IDs selected by an entity-instance/residue feature."""
    chain_ids = []
    for asym in getattr(feature, "asym_units", []) or []:
        chain_id = _value(getattr(asym, "id", None))
        if chain_id and chain_id not in chain_ids:
            chain_ids.append(chain_id)
    for residue in getattr(feature, "residues", []) or []:
        chain_id = _residue_chain_id(residue)
        if chain_id and chain_id not in chain_ids:
            chain_ids.append(chain_id)
    return chain_ids


def _metric_scope(metric):
    """Describe the chain or chain pair selected by a metric, if available."""
    feature = getattr(metric, "feature", None)
    if feature is not None:
        chains = _feature_chain_ids(feature)
        if chains:
            return "Chain " + ",".join(chains)

    feature1 = getattr(metric, "feature1", None)
    feature2 = getattr(metric, "feature2", None)
    if feature1 is not None and feature2 is not None:
        chains1, chains2 = _feature_chain_ids(feature1), _feature_chain_ids(feature2)
        if chains1 and chains2:
            return f"Chains {','.join(chains1)}–{','.join(chains2)}"

    residue = getattr(metric, "residue", None)
    if residue is not None:
        chain = _residue_chain_id(residue)
        if chain:
            return f"Chain {chain}"
    residue1 = getattr(metric, "residue1", None)
    residue2 = getattr(metric, "residue2", None)
    if residue1 is not None and residue2 is not None:
        chain1, chain2 = _residue_chain_id(residue1), _residue_chain_id(residue2)
        if chain1 and chain2:
            return f"Chains {chain1}–{chain2}"
    return ""


def _reviewer_metric_name(name):
    """Remove scope wording that is made explicit in the table item."""
    return re.sub(r"\s+per\s+(?:chain|chain pair)$", "", name,
                  flags=re.IGNORECASE)


def _data_label(data):
    if isinstance(data, (list, tuple, set)):
        labels = [_data_label(item) for item in data]
        return "; ".join(label for label in labels if label)
    return (_value(getattr(data, "name", None))
            or _value(getattr(data, "description", None))
            or type(data).__name__)


def _associated_files(repository, files=None, prefix=""):
    for associated_file in files if files is not None else getattr(repository, "files", []):
        path = (_value(getattr(associated_file, "path", None))
                or _value(getattr(associated_file, "file_url", None)))
        nested_path = "/".join(part for part in (prefix, path) if part)
        yield associated_file, nested_path
        nested = getattr(associated_file, "files", None)
        if nested:
            yield from _associated_files(repository, nested, nested_path)


def _metric_summary(metrics):
    """Report chain metrics directly and summarize dense metric collections."""
    grouped = defaultdict(list)
    for metric in metrics:
        value = _metric_value(metric)
        if value is not None:
            key = (_metric_name(metric), _metric_mode(metric), _metric_scope(metric))
            grouped[key].append(value)

    for (name, mode, scope), values in grouped.items():
        display_name = _reviewer_metric_name(name) if scope else name
        if scope:
            display_name = f"{scope} {display_name}"
        elif mode == "local":
            display_name = f"Residue {display_name}"
        elif mode == "local-pairwise":
            display_name = f"Pairwise {display_name}"
        if len(values) == 1:
            result = _format_number(values[0])
            note = f"ModelCIF metric mode: {mode}"
        else:
            result = (
                f"median {_format_number(statistics.median(values))}; "
                f"mean {_format_number(sum(values) / len(values))}; "
                f"range {_format_number(min(values))}–{_format_number(max(values))}"
            )
            note = f"Summary of {len(values):,} {mode} values; individual values remain in the ModelCIF"
        yield display_name, result, note


def _rows(system):
    """Yield a curated SI summary rather than a category-by-category CIF dump."""
    title = _value(getattr(system, "title", None)) or "Untitled prediction"
    yield "Prediction overview", "Prediction", title, ""

    entities = list(getattr(system, "entities", []) or [])
    asym_units = list(getattr(system, "asym_units", []) or [])
    groups = list(getattr(system, "model_groups", []) or [])
    model_count = sum(len(list(group)) for group in groups)
    yield "Prediction overview", "Composition", (
        f"{len(asym_units)} chain(s), {len(entities)} unique molecular entity/entities"
    ), "Repeated chains can refer to the same entity"
    yield "Prediction overview", "Predicted models", str(model_count), (
        f"Organized into {len(groups)} model group(s)"
    )

    authors = [_value(author) for author in getattr(system, "authors", []) or []]
    if authors:
        yield "Provenance", "Model authors", "; ".join(authors), ""
    for citation in getattr(system, "citations", []) or []:
        title = _value(getattr(citation, "title", None)) or "Method citation"
        identifiers = []
        doi = _value(getattr(citation, "doi", None))
        pmid = _value(getattr(citation, "pmid", None))
        if doi:
            identifiers.append(f"DOI {doi}")
        if pmid:
            identifiers.append(f"PMID {pmid}")
        yield "Provenance", "Method citation", title, "; ".join(identifiers)
    for grant in getattr(system, "grants", []) or []:
        agency = _value(getattr(grant, "funding_organization", None))
        grant_id = _value(getattr(grant, "grant_number", None))
        country = _value(getattr(grant, "country", None))
        yield "Provenance", "Funding", agency or grant_id, "; ".join(
            part for part in (grant_id if agency else "", country) if part
        )
    for revision in getattr(system, "revisions", []) or []:
        date = _value(getattr(revision, "date", None))
        version = ".".join(
            _value(getattr(revision, field, None)) for field in ("major", "minor")
        )
        yield "Provenance", "ModelCIF revision", date or version, (
            f"Version {version}" if date and version else ""
        )
    for usage in getattr(system, "data_usage", []) or []:
        kind = type(usage).__name__
        details = _value(getattr(usage, "details", None))
        url = _value(getattr(usage, "url", None))
        yield "Data use", kind, details or _value(getattr(usage, "name", None)), url

    entity_numbers = {id(entity): index for index, entity in enumerate(entities, 1)}
    for index, entity in enumerate(entities, 1):
        sequence = _sequence(entity)
        description = _value(getattr(entity, "description", None)) or "Target molecule"
        chain_ids = [
            _value(getattr(asym, "id", None))
            for asym in asym_units if getattr(asym, "entity", None) is entity
        ]
        result = f"{description}; {len(sequence)} residues" if sequence else description
        note = f"Chain(s): {', '.join(chain_ids)}" if chain_ids else ""
        yield "Target composition", f"Entity {index}", result, note
        references = getattr(entity, "references", []) or []
        for reference in references:
            database = (_value(getattr(reference, "db_name", None))
                        or _value(getattr(reference, "database", None)))
            accession = (_value(getattr(reference, "accession", None))
                         or _value(getattr(reference, "db_code", None)))
            organism = _value(getattr(reference, "organism_scientific", None))
            begin = _value(getattr(reference, "align_begin", None))
            end = _value(getattr(reference, "align_end", None))
            notes = [f"Applies to entity {index}"]
            if organism:
                notes.append(organism)
            if begin and end:
                notes.append(f"reference residues {begin}–{end}")
            yield "Target composition", "Sequence database reference", (
                ":".join(part for part in (database, accession) if part)
            ), "; ".join(notes)

    for asym in asym_units:
        chain_id = _value(getattr(asym, "id", None)) or "Unlabelled"
        entity_number = entity_numbers.get(id(getattr(asym, "entity", None)), "?")
        details = _value(getattr(asym, "details", None))
        yield "Target composition", f"Chain {chain_id}", f"Entity {entity_number}", details

    seen_software = set()
    seen_settings = set()
    for software in getattr(system, "software", []) or []:
        label = _software_label(software)
        if not label or label in seen_software:
            continue
        seen_software.add(label)
        classification = _value(getattr(software, "classification", None))
        description = _value(getattr(software, "description", None))
        yield "Prediction method", "Software", label, classification or description
        parameters = _parameters(software)
        if parameters:
            seen_settings.update(parameters)
            yield "Prediction method", f"Settings for {label}", "; ".join(parameters), ""

    for software_group in getattr(system, "software_groups", []) or []:
        label = _software_label(software_group) or "prediction software"
        parameters = [p for p in _parameters(software_group) if p not in seen_settings]
        if parameters:
            seen_settings.update(parameters)
            yield "Prediction method", f"Settings for {label}", "; ".join(parameters), ""

    file_parameters = [
        parameter for parameter in getattr(system, "_si_file_parameters", [])
        if parameter not in seen_settings
    ]
    if file_parameters:
        seen_settings.update(file_parameters)
        yield "Prediction method", "Recorded model settings", "; ".join(file_parameters), (
            "Read directly from the ModelCIF software-parameter table"
        )

    for protocol_index, protocol in enumerate(getattr(system, "protocols", []) or [], 1):
        for step_index, step in enumerate(getattr(protocol, "steps", []) or [], 1):
            name = _value(getattr(step, "name", None)) or type(step).__name__
            software = getattr(step, "software", None)
            software_label = _software_label(software) if software is not None else ""
            details = _value(getattr(step, "details", None))
            result = software_label or details or "Recorded in ModelCIF"
            note = details if software_label and details else ""
            yield "Prediction method", f"Step {protocol_index}.{step_index}: {name}", result, note
            input_data = getattr(step, "input_data", None)
            output_data = getattr(step, "output_data", None)
            if input_data is not None:
                yield "Prediction method", f"Input to step {protocol_index}.{step_index}", (
                    _data_label(input_data)
                ), ""
            if output_data is not None:
                yield "Prediction method", f"Output from step {protocol_index}.{step_index}", (
                    _data_label(output_data)
                ), ""
            parameters = _parameters(software) if software is not None else []
            if parameters:
                yield "Prediction method", f"Settings for step {protocol_index}.{step_index}", (
                    "; ".join(parameters)
                ), ""

    for group_index, group in enumerate(groups, 1):
        group_name = _value(getattr(group, "name", None)) or f"Model group {group_index}"
        for model_index, model in enumerate(list(group), 1):
            model_name = _value(getattr(model, "name", None)) or f"Model {model_index}"
            model_type = _value(getattr(model, "model_type", None))
            yield "Models and confidence", model_name, group_name, (
                f"Model type: {model_type}" if model_type else ""
            )
            for metric_name, result, note in _metric_summary(
                getattr(model, "qa_metrics", []) or []
            ):
                yield "Models and confidence", f"{model_name}: {metric_name}", result, note
            omitted = getattr(model, "not_modeled_residue_ranges", []) or []
            for omitted_range in omitted:
                asym = getattr(omitted_range, "asym_unit", None) or getattr(omitted_range, "asym", None)
                chain = _value(getattr(asym, "id", None))
                begin = _value(getattr(omitted_range, "seq_id_begin", None))
                end = _value(getattr(omitted_range, "seq_id_end", None))
                yield "Models and confidence", f"{model_name}: unmodeled region", (
                    f"chain {chain}, residues {begin}–{end}"
                ), "Coordinates are intentionally absent"
        representatives = getattr(group, "representatives", []) or []
        for representative in representatives:
            model = getattr(representative, "model", representative)
            yield "Models and confidence", "Representative model", (
                _value(getattr(model, "name", None)) or "Selected representative"
            ), _value(getattr(representative, "details", None))

    for index, alignment in enumerate(getattr(system, "alignments", []) or [], 1):
        pair_count = len(getattr(alignment, "pairs", []) or [])
        yield "Templates and alignments", f"Alignment {index}", (
            _value(getattr(alignment, "name", None)) or type(alignment).__name__
        ), f"{pair_count} target-template pair(s)" if pair_count else ""

    for index, template in enumerate(getattr(system, "templates", []) or [], 1):
        name = (_value(getattr(template, "name", None))
                or _value(getattr(template, "id", None)) or f"Template {index}")
        details = _value(getattr(template, "details", None))
        yield "Templates and alignments", f"Template {index}", name, details

    for data in getattr(system, "data", []) or []:
        if type(data).__name__ == "ReferenceDatabase":
            version = _value(getattr(data, "version", None))
            location = _value(getattr(data, "location_url", None))
            yield "Prediction method", "Reference database", _data_label(data), (
                "; ".join(part for part in (f"version {version}" if version else "", location) if part)
            )

    for repository in getattr(system, "repositories", []) or []:
        root = _value(getattr(repository, "url_root", None))
        for associated_file, path in _associated_files(repository):
            details = _value(getattr(associated_file, "details", None))
            location = f"{root.rstrip('/')}/{path.lstrip('/')}" if root and path else (path or root)
            yield "Supporting data", details or "Associated file", location, (
                _value(getattr(associated_file, "file_content", None))
            )


def _write_tsv(rows, output_handle, columns=SI_COLUMNS):
    writer = csv.writer(output_handle, delimiter="\t", lineterminator="\n")
    writer.writerow(columns)
    writer.writerows(rows)


def _markdown_cell(value):
    return _value(value).replace("|", "\\|").replace("\n", " ")


def _write_markdown(rows, output_handle, columns=SI_COLUMNS):
    output_handle.write("| " + " | ".join(columns) + " |\n")
    output_handle.write("| " + " | ".join("---" for _ in columns) + " |\n")
    for row in rows:
        output_handle.write("| " + " | ".join(_markdown_cell(value) for value in row) + " |\n")


def write_metadata(input_path, output_handle, output_format="tsv"):
    systems = _read_systems(input_path)
    if not systems:
        raise ValueError(f"No ModelCIF data blocks found in {input_path}")

    rows = []
    for system_index, system in enumerate(systems, 1):
        system_name = (_value(getattr(system, "id", None))
                       or os.path.basename(input_path) or str(system_index))
        rows.extend((system_name, section, item, result, note)
                    for section, item, result, note in _rows(system))

    columns = ("System",) + SI_COLUMNS
    if output_format == "markdown":
        _write_markdown(rows, output_handle, columns)
    else:
        _write_tsv(rows, output_handle, columns)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input ModelCIF (.cif, .mmcif, or .bcif) file")
    parser.add_argument("-o", "--output", help="Output path (default: stdout)")
    parser.add_argument(
        "--format", choices=("tsv", "markdown"), default="tsv",
        help="Reviewer table format (default: tsv)",
    )
    args = parser.parse_args(argv)
    if args.output:
        with open(args.output, "w", newline="") as output_handle:
            write_metadata(args.input, output_handle, args.format)
    else:
        write_metadata(args.input, sys.stdout, args.format)


if __name__ == "__main__":
    main()
