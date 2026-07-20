#!/usr/bin/env python3
"""
Convert protein structure prediction outputs (PDB or mmCIF) to a
modelCIF-compliant mmCIF file.

With aim to be directly depositable in ModelArchive.

Includes maximal metadata by default

Note: PAE will *not* be embedded due to size constraints, instead linked as an associated file

Can also create .bcif for space reasons
"""

import argparse
import csv
import os
import sys
import yaml

import modelcif
import modelcif.model
import modelcif.dumper
import modelcif.qa_metric
import modelcif.protocol
import modelcif.data
import modelcif.associated

from Bio import PDB
from Bio.PDB.Polypeptide import protein_letters_3to1 as _aa3to1

# Static metadata per prediction program: (display_name, url, classification).
# Version is absent — it is read at runtime from the upstream versions.yml so
# it always reflects the actual container/tool version that ran.
_SOFTWARE_INFO = {
    'alphafold2':           ('AlphaFold2',            'https://github.com/google-deepmind/alphafold',         'protein structure prediction'),
    'alphafold3':           ('AlphaFold3',            'https://github.com/google-deepmind/alphafold3',        'protein structure prediction'),
    'boltz':                ('Boltz',                 'https://github.com/jwohlwend/boltz',                   'protein structure prediction'),
    'colabfold':            ('ColabFold',             'https://github.com/sokrypton/ColabFold',               'protein structure prediction'),
    'esmfold':              ('ESMFold',               'https://github.com/facebookresearch/esm',              'protein structure prediction'),
    'helixfold3':           ('HelixFold3',            'https://github.com/PaddlePaddle/PaddleHelix',          'protein structure prediction'),
    'rosettafold2na':       ('RoseTTAFold2NA',        'https://github.com/uw-ipd/RoseTTAFold2NA',             'protein structure prediction'),
    'rosettafold_all_atom': ('RoseTTAFold-All-Atom',  'https://github.com/baker-laboratory/RoseTTAFold-All-Atom', 'protein structure prediction'),
}

def parse_args(args=None):
    parser = argparse.ArgumentParser(
        description='Generate a valid modelCIF structure file (according to ModelArchive dictionary) from the various metrics .tsv files, and program execution details.'
    )
    parser.add_argument('--structs', required=True, nargs='+',
                        help='Input structure files (PDB or mmCIF), one per rank in rank order.')
    parser.add_argument('--msa',     required=True, help='*_msa.tsv from extract_metrics.py.')
    parser.add_argument('--plddt',   required=True, help='*_plddt.tsv from extract_metrics.py.')
    parser.add_argument('--pae-embed', action='store_true', help='Embed PAE as local-pairwise QA metrics in the primary modelCIF instead of as an associated file.')
    parser.add_argument('--pae',     required=True, help='*_pae.tsv from extract_metrics.py.')
    parser.add_argument('--ptm',     required=True, help='*_ptm.tsv from extract_metrics.py.')
    parser.add_argument('--iptm',    required=True, help='*_iptm.tsv from extract_metrics.py.')
    parser.add_argument('--name',    required=True)
    parser.add_argument('--prog',         required=True)
    parser.add_argument('--msa_tool',     default=None, help='MSA search tool used (e.g. jackhmmer, hhblits, mmseqs2). Embedded in the CoevolutionMSA protocol step.')
    parser.add_argument('--versions_yml', default=None, help='versions.yml emitted by the upstream run_* module.')
    parser.add_argument('--software_details', default=None, help='Optional path to DUMMY YAML file for software + protocol step metadata -- pre-wiring into upstream logic.')
    parser.add_argument('--output',       default=None)
    parser.add_argument('--all-structs',  action='store_true', help='Include all parseable files passed via --structs as models. Default when this flag is not present is that only the first structure is used.')
    parser.add_argument('--write_binary', action='store_true', help='Write BinaryCIF (.bcif) output instead of text mmCIF. Requires the msgpack package.')
    return parser.parse_args(args)


# ---------------------------------------------------------------------------
# Structure helpers
# ---------------------------------------------------------------------------

# So proteinfold can handle the structure files from any ${meta.mode} structure prediction module
def _parse_structure(struct_file):
    """Parse a PDB or mmCIF file with BioPython and return the structure."""
    ext = os.path.splitext(struct_file)[1].lower()
    if ext in ('.cif', '.mmcif'):
        parser = PDB.MMCIFParser(QUIET=True)
    elif ext == '.pdb':
        parser = PDB.PDBParser(QUIET=True)
    else:
        raise ValueError(
            f"Unsupported structure format: {ext} for file {struct_file}"
            "Expected .pdb, .cif, or .mmcif")
    return parser.get_structure('model', struct_file)


def _chain_sequence(chain):
    """Return the single-letter amino-acid sequence for standard residues."""
    seq = []
    for res in chain.get_residues():
        if res.id[0] != ' ':   # skip HETATM records (ligands, waters)
            continue
        seq.append(_aa3to1.get(res.resname.strip(), 'X'))
    return ''.join(seq)


def _read_sw_version(versions_yml, prog):
    """
    Extract the version string for *prog* from a Nextflow versions.yml.

    TODO: this currently assumes a simple structure of versions.yml and I'm not sure if that's settled.

    """
    if versions_yml is None or not os.path.exists(versions_yml):
        return None
    with open(versions_yml) as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict):
        return None
    # The single top-level key is the process name; we don't care what it is.
    process_versions = next(iter(data.values()), {})
    return process_versions.get(prog.lower())


def _read_software_details_yml(software_details):
    """Load software/protocol metadata from an explicit YAML path."""
    if software_details in (None, 'None'):
        return {}
    if not os.path.exists(software_details):
        raise ValueError(f"software_details file not found: {software_details}")
    with open(software_details) as fh:
        data = yaml.safe_load(fh)
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise ValueError(
            f"software_details YAML must be a mapping/object, got {type(data).__name__}: {software_details}"
        )
    return data


def _deep_merge_dict(base, override):
    """Recursively merge two dicts, preferring values from *override*."""
    out = dict(base)
    for key, value in override.items():
        if (
            key in out
            and isinstance(out[key], dict)
            and isinstance(value, dict)
        ):
            out[key] = _deep_merge_dict(out[key], value)
        else:
            out[key] = value
    return out


def _software_from_spec(spec, fallback_name, fallback_location, fallback_classification, fallback_description, fallback_version=None):
    """Create modelcif.Software from a spec dict with sensible fallbacks."""
    return modelcif.Software(
        name=spec.get('name', fallback_name),
        classification=spec.get('classification', fallback_classification),
        description=spec.get('description', fallback_description),
        location=spec.get('location', fallback_location),
        type=spec.get('type', 'program'),
        version=spec.get('version', fallback_version),
    )


def _step_software(main_software, execution_software, step_cfg):
    """Resolve protocol step software as Software or SoftwareGroup."""
    use_main = step_cfg.get('use_main_software', True)
    use_execution = step_cfg.get('use_execution_software', False)

    members = []
    if use_main and main_software is not None:
        members.append(main_software)
    if use_execution and execution_software is not None:
        members.append(execution_software)

    if not members:
        return main_software
    if len(members) == 1:
        return members[0]
    return modelcif.SoftwareGroup(members)

# Some of these parsers should be recombined with utils.py once new generate_report.py refactor merged - KR

def _read_msa_tsv(msa_tsv):
    """
    Parse the *_msa.tsv written by extract_metrics.py.

    The file has no header; each row is one homologous sequence encoded as
    tab-separated integers (0-21 per residue position).

    Returns ``(num_seqs, alignment_length)`` where *num_seqs* is the MSA
    depth and *alignment_length* is the number of residue columns.
    """
    num_seqs = 0
    alignment_length = 0
    with open(msa_tsv) as fh:
        for line in fh:
            line = line.rstrip('\n')
            if not line:
                continue
            num_seqs += 1
            if alignment_length == 0:
                alignment_length = len(line.split('\t'))
    return num_seqs, alignment_length


def _read_plddt_tsv(plddt_tsv):
    """
    Parse the *_plddt.tsv written by extract_metrics.py.

    Returns a dict mapping each rank label (e.g. ``'rank_0'``) to a list of
    per-residue pLDDT floats in residue order.  The dict is ordered by rank
    index so that ``zip(struct_files, plddt_by_rank.values())`` pairs them
    correctly.
    """
    with open(plddt_tsv) as fh:
        reader = csv.DictReader(fh, delimiter='\t')
        rows = list(reader)
    rank_cols = sorted(
        # TODO: need to garuantee that 'rank_X' is always in the tsv spec
        (k for k in rows[0].keys() if k.startswith('rank_')),
        key=lambda k: int(k.split('_', 1)[1]),
    )
    return {col: [float(row[col]) for row in rows] for col in rank_cols}


def _read_ranked_score_tsv(tsv_file):
    scores = {}
    with open(tsv_file) as fh:
        for row in csv.reader(fh, delimiter='\t'):
            if len(row) < 2:
                raise ValueError(f"Malformed row in {tsv_file}: {row!r}")
            rank, value = row[0].strip(), row[1].strip()
            if not rank or not value:
                raise ValueError(f"Empty rank or value in {tsv_file}: {row!r}")
            if not rank.startswith('rank_'):
                try:
                    rank = f"rank_{int(rank)}"
                except ValueError:
                    continue
            try:
                scores[rank] = float(value)
            except ValueError:
                continue
    return scores


def _read_pae_tsv(pae_tsv):
    matrix = []
    with open(pae_tsv) as fh:
        for row in csv.reader(fh, delimiter='\t'):
            if not row:
                continue
            matrix.append([float(v) for v in row])

    if not matrix:
        raise ValueError(f"Empty PAE file: {pae_tsv}")

    ncols = len(matrix[0])
    if ncols == 0 or any(len(r) != ncols for r in matrix):
        raise ValueError(f"Non-rectangular PAE matrix in {pae_tsv}")

    return matrix


def _read_ptm_tsv(ptm_tsv):
    return _read_ranked_score_tsv(ptm_tsv)


def _read_iptm_tsv(iptm_tsv):
    return _read_ranked_score_tsv(iptm_tsv)


# ---------------------------------------------------------------------------
# modelcif Model subclass
# ---------------------------------------------------------------------------

class _StructureModel(modelcif.model.AbInitioModel):
    """Wrap a BioPython structure as a modelCIF AbInitioModel."""

    # While AlphaFold does use templates and MSAs for homology, the deep learning methods are a different approach and *can* be run template and MSA-free
    # I think "ab initio" is still the best fit for the modelCIF class features, and wider support for various EvoFormer base models
    # I was planning to capture MSA, DB, and template in the protocol steps --helped by nextflow-- rather than as an inseparable model attribute.
    # See (to be implemented later) .protoctol.TemplateSearch() and .protocol.CoevolutionMSA() in the modelCIF spec

    def __init__(self, assembly, asym_map, biopython_structure, **kwargs):
        super().__init__(assembly=assembly, **kwargs)
        self._biopy_struct = biopython_structure
        self._asym_map = asym_map  # chain_id -> modelcif.AsymUnit

    # By defining the get_atoms() generator the modelcif library will populate model.atoms cleanly from BioPython structure data
    def get_atoms(self):
        bp_model = next(self._biopy_struct.get_models())
        for chain in bp_model:
            asym = self._asym_map.get(chain.id)
            if asym is None:
                continue
            seq_id = 1
            for res in chain.get_residues():
                if res.id[0] != ' ':   # skip HETATM
                    continue
                for atom in res.get_atoms():
                    elem = (atom.element or atom.name[0]).strip().capitalize()
                    # Remember this is basically BioPython PDB .atom() data -> modelcif.model.Atom, so we have to convert types and rename some fields.
                    yield modelcif.model.Atom(
                        asym_unit=asym,
                        seq_id=seq_id,
                        atom_id=atom.name,
                        type_symbol=elem,
                        x=float(atom.coord[0]),
                        y=float(atom.coord[1]),
                        z=float(atom.coord[2]),
                        het=False,
                        biso=float(atom.bfactor),
                        occupancy=float(atom.occupancy),
                    )
                seq_id += 1


# ---------------------------------------------------------------------------
# Piece together the modelCIF system from the structure and pLDDT data
# ---------------------------------------------------------------------------

def build_modelcif(
    struct_files,
    plddt_file,
    msa_file,
    pae_file,
    pae_embed,
    ptm_file,
    iptm_file,
    name,
    prog,
    sw_version=None,
    msa_tool=None,
    software_details=None,
    all_structs=False,
):
    """
    Build a modelcif.System from ranked structure files and QA metric .tsv files.

    Parameters
    ----------
    struct_files : list[str]
        Paths to PDB or mmCIF input structures, one per rank in rank order.
        Each file becomes a separate model in the output ModelGroup.
    plddt_file : str
        Path to *_plddt.tsv from extract_metrics.py.
    msa_file : str
        Path to *_msa.tsv from extract_metrics.py.
    pae_file : str
        Path to *_pae.tsv from extract_metrics.py.
    pae_embed : bool
        If True, embed PAE values as local-pairwise QA metrics in the main
        modelCIF. If False, keep PAE as an associated QA metrics file.
    ptm_file : str
        Path to *_ptm.tsv from extract_metrics.py.
    iptm_file : str
        Path to *_iptm.tsv from extract_metrics.py.
    name : str
        Sample / sequence identifier used in titles and file naming.
    prog : str
        Prediction program key (see _SOFTWARE_INFO).
    sw_version : str, optional
        Version string parsed from the upstream versions.yml.
    msa_tool : str, optional
        MSA search tool name (e.g. ``'jackhmmer'``, ``'hhblits'``, ``'mmseqs2'``).
        Embedded in the CoevolutionMSA protocol step name.

    Returns
    -------
    modelcif.System
    """
    software_details = software_details or {}

    selected_struct_files = []
    biopy_structs = []

    if all_structs:
        for struct_file in struct_files:
            try:
                biopy_struct = _parse_structure(struct_file)
            except Exception as err:
                print(
                    f"Skipping unparseable structure file {struct_file}: {err}",
                    file=sys.stderr,
                )
                continue
            selected_struct_files.append(struct_file)
            biopy_structs.append(biopy_struct)

        if not biopy_structs:
            raise ValueError(
                'No parseable structures found in --structs input while using --all-structs'
            )
    else:
        selected_struct_files = [struct_files[0]]
        biopy_structs = [_parse_structure(struct_files[0])]
    plddt_by_rank = _read_plddt_tsv(plddt_file)
    ptm_by_rank = _read_ptm_tsv(ptm_file)
    iptm_by_rank = _read_iptm_tsv(iptm_file)
    pae_matrix = _read_pae_tsv(pae_file) if pae_embed else None
    msa_num_seqs, msa_length = _read_msa_tsv(msa_file)

    system = modelcif.System(title=f'{name} predicted by {prog}')

    # ---- Entities & AsymUnits -------------------------------------------
    # Derived from rank_0; all ranked structures share the same target sequence
    # so entities and asym units are identical across ranks.
    bp_model_0 = next(biopy_structs[0].get_models())
    seen_seqs = {}   # sequence -> modelcif.Entity
    asym_map = {}    # chain_id -> modelcif.AsymUnit

    for chain in bp_model_0:
        seq = _chain_sequence(chain)
        if not seq:
            continue
        entity = seen_seqs.get(seq)
        if entity is None:
            entity = modelcif.Entity(seq, description=name)
            system.entities.append(entity)
            seen_seqs[seq] = entity
        asym = modelcif.AsymUnit(entity, details=f'chain {chain.id}', id=chain.id)
        system.asym_units.append(asym)
        asym_map[chain.id] = asym

    if not asym_map:
        raise ValueError(
            f'No standard polymer residues found in {selected_struct_files[0]}. '
            'Cannot build modelCIF system.'
        )

    assembly = modelcif.Assembly(list(asym_map.values()), name='Modelled assembly')

    # ---- Software -------------------------------------------------------
    info = _SOFTWARE_INFO.get(prog.lower())
    if info:
        sw_name, sw_location, sw_classification = info
    else:
        sw_name           = prog
        sw_location       = 'unknown'
        sw_classification = 'protein structure prediction'

    details_defaults = software_details.get('defaults', {})
    details_programs = software_details.get('programs', {})
    details_for_prog = details_programs.get(prog.lower(), {})

    modeling_sw_cfg = _deep_merge_dict(
        details_defaults.get('modeling_software', {}),
        details_for_prog.get('modeling_software', {}),
    )
    execution_sw_cfg = _deep_merge_dict(
        details_defaults.get('execution_software', {}),
        details_for_prog.get('execution_software', {}),
    )
    protocol_cfg = _deep_merge_dict(
        details_defaults.get('protocol', {}),
        details_for_prog.get('protocol', {}),
    )

    software = _software_from_spec(
        modeling_sw_cfg,
        fallback_name=sw_name,
        fallback_location=sw_location,
        fallback_classification=sw_classification,
        fallback_description=f'{sw_name} structure prediction',
        fallback_version=sw_version,
    )
    system.software.append(software)

    execution_software = None
    if execution_sw_cfg.get('enabled', False):
        execution_software = _software_from_spec(
            execution_sw_cfg,
            fallback_name='Workflow execution engine',
            fallback_location='unknown',
            fallback_classification='workflow management',
            fallback_description='Workflow execution environment',
            fallback_version=None,
        )
        system.software.append(execution_software)

    # ---- pLDDT QA metric class ------------------------------------------
    class LocalPLDDT(modelcif.qa_metric.Local, modelcif.qa_metric.PLDDT):
        """Predicted lDDT-CA score in [0,100] output by the folding software"""

    LocalPLDDT.software = software

    class GlobalPTM(modelcif.qa_metric.Global, modelcif.qa_metric.PTM):
        """Predicted TM-score for the full model in [0,1]."""

    GlobalPTM.software = software

    class GlobalIpTM(modelcif.qa_metric.Global, modelcif.qa_metric.IpTM):
        """Predicted interface TM-score for multichain complexes in [0,1]."""

    GlobalIpTM.software = software

    class LocalPairwisePAE(modelcif.qa_metric.LocalPairwise, modelcif.qa_metric.PAE):
        """Predicted aligned error between residue pairs."""

    LocalPairwisePAE.software = software

    # ---- One model per ranked structure ---------------------------------
    # Iterate over every provided structure file; rank_N QA metrics are
    # attached when available, but models are still emitted if extra
    # structures are provided beyond ranked metric columns.
    models = []
    for idx, biopy_struct in enumerate(biopy_structs):
        rank_key = f'rank_{idx}'
        plddt_values = plddt_by_rank.get(rank_key)
        bp_model_i = next(biopy_struct.get_models())
        model = _StructureModel(
            assembly=assembly,
            asym_map=asym_map,
            biopython_structure=biopy_struct,
            name=f'{name} {rank_key}',
        )

        # Assign per-residue pLDDT for this rank in residue order across all
        # chains, matching the column order written by
        # extract_metrics.extract_structs_plddt_to_tsv.
        if plddt_values is not None:
            plddt_iter = iter(plddt_values)
            for chain in bp_model_i:
                asym = asym_map.get(chain.id)
                if asym is None:
                    continue
                seq_id = 1
                for res in chain.get_residues():
                    if res.id[0] != ' ':
                        continue
                    try:
                        plddt_value = next(plddt_iter)
                    except StopIteration as err:
                        raise ValueError(
                            f'Insufficient pLDDT values for {rank_key} in {plddt_file}'
                        ) from err
                    model.qa_metrics.append(
                        LocalPLDDT(asym.residue(seq_id), plddt_value)
                    )
                    seq_id += 1

        if pae_embed:
            model_residues = []
            for chain in bp_model_i:
                asym = asym_map.get(chain.id)
                if asym is None:
                    continue
                seq_id = 1
                for res in chain.get_residues():
                    if res.id[0] != ' ':
                        continue
                    model_residues.append(asym.residue(seq_id))
                    seq_id += 1

            num_res = len(model_residues)
            if len(pae_matrix) != num_res or len(pae_matrix[0]) != num_res:
                raise ValueError(
                    f"PAE matrix shape {len(pae_matrix)}x{len(pae_matrix[0])} does not match "
                    f"the model residue count ({num_res}) for {rank_key}"
                )

            for i, residue_i in enumerate(model_residues):
                for j, residue_j in enumerate(model_residues):
                    model.qa_metrics.append(
                        LocalPairwisePAE(residue_i, residue_j, pae_matrix[i][j])
                    )

        if rank_key in ptm_by_rank:
            model.qa_metrics.append(GlobalPTM(ptm_by_rank[rank_key]))
        if rank_key in iptm_by_rank:
            model.qa_metrics.append(GlobalIpTM(iptm_by_rank[rank_key]))

        models.append(model)

    # So model.ModelGroup is great here since every single inference from a multi-model method (e.g. AlphaFold)
    # is captured coordinates-wise as a separate structure to inspect, but the protocol and software metadata is shared across them.
    # TODO: double-check these open as separate #X.Y models in ChineraX
    model_group = modelcif.model.ModelGroup(models, name='All models')
    system.model_groups.append(model_group)

    # ---- Protocol -------------------------------------------------------
    protocol = modelcif.protocol.Protocol()

    msa_step_cfg = protocol_cfg.get('msa_step', {})
    modeling_step_cfg = protocol_cfg.get('modeling_step', {})

    msa_data = modelcif.data.Data(
        'Coevolution MSA',
        details=f'{msa_num_seqs} sequences, {msa_length} columns',
    )
    system.data.append(msa_data)
    msa_step = modelcif.protocol.CoevolutionMSAStep(
        input_data=modelcif.data.DataGroup(list(seen_seqs.values())),
        output_data=msa_data,
        name=msa_step_cfg.get('name', msa_tool),
        details=msa_step_cfg.get('details'),
        software=_step_software(software, execution_software, msa_step_cfg),
    )
    protocol.steps.append(msa_step)

    # Modeling step: MSA is the input; ranked models are the output.
    step = modelcif.protocol.ModelingStep(
        input_data=msa_data,
        output_data=modelcif.data.DataGroup(models),
        name=modeling_step_cfg.get('name', 'Structure prediction'),
        details=modeling_step_cfg.get('details'),
        software=_step_software(software, execution_software, modeling_step_cfg),
    )
    protocol.steps.append(step)
    system.protocols.append(protocol)

    if not pae_embed:
        pae_data = modelcif.data.Data(
            'Predicted aligned error matrix',
            details='Per-rank PAE matrices exported as TSV from extract_metrics.py',
        )
        system.data.append(pae_data)
        pae_associated = modelcif.associated.QAMetricsFile(
            path=os.path.basename(pae_file),
            details='Predicted aligned error (PAE) values for this entry',
            data=pae_data,
        )
        system.repositories.append(
            modelcif.associated.Repository(url_root=None, files=[pae_associated])
        )

    return system


def main(args=None):
    args = parse_args(args)

    if args.write_binary:
        import msgpack  # Only required when writing BinaryCIF; not a hard dependency otherwise. Should be environment.yml but being defensive
        output_file = args.output or f'{args.name}_{args.prog}.bcif'
        open_mode, fmt = 'wb', 'BCIF'
    else:
        output_file = args.output or f'{args.name}_{args.prog}.mmcif'
        open_mode, fmt = 'w', 'mmCIF'

    sw_version = _read_sw_version(args.versions_yml, args.prog)
    software_details = _read_software_details_yml(args.software_details)
    # Nextflow emits the string 'None' when no msa_tool is known; normalise to Python None.
    msa_tool = None if args.msa_tool in (None, 'None') else args.msa_tool
    system = build_modelcif(
        struct_files=args.structs,
        all_structs=args.all_structs,
        plddt_file=args.plddt,
        msa_file=args.msa,
        pae_file=args.pae,
        pae_embed=args.pae_embed,
        ptm_file=args.ptm,
        iptm_file=args.iptm,
        name=args.name,
        prog=args.prog,
        sw_version=sw_version,
        msa_tool=msa_tool,
        software_details=software_details,
    )

    with open(output_file, open_mode) as fh:
        modelcif.dumper.write(fh, [system], format=fmt)

    print(f'Written: {output_file}', file=sys.stderr)


if __name__ == '__main__':
    main()
