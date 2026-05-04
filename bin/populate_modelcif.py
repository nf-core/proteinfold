#!/usr/bin/env python3
"""
Convert protein structure prediction outputs (PDB or mmCIF) to a
modelCIF-compliant mmCIF file. 

With aim to be directly depositable in ModelArchive.

Includes maximal metadata by default

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
        description='Convert a structure prediction to modelCIF with pLDDT annotations.'
    )
    parser.add_argument('--structs', required=True, nargs='+',
                        help='Input structure files (PDB or mmCIF), one per rank in rank order.')
    parser.add_argument('--msa',     required=True, help='*_msa.tsv from extract_metrics.py.')
    parser.add_argument('--plddt',   required=True, help='*_plddt.tsv from extract_metrics.py.')
    parser.add_argument('--pae',     required=True, help='*_pae.tsv from extract_metrics.py.')
    parser.add_argument('--ptm',     required=True, help='*_ptm.tsv from extract_metrics.py.')
    parser.add_argument('--iptm',    required=True, help='*_iptm.tsv from extract_metrics.py.')
    parser.add_argument('--name',    required=True)
    parser.add_argument('--prog',         required=True)
    parser.add_argument('--versions_yml', default=None, help='versions.yml emitted by the upstream run_* module.')
    parser.add_argument('--output',       default=None)
    parser.add_argument('--write_binary', action='store_true',
                        help='Write BinaryCIF (.bcif) output instead of text mmCIF. Requires the msgpack package.')
    return parser.parse_args(args)


# ---------------------------------------------------------------------------
# Structure helpers
# ---------------------------------------------------------------------------

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

    The file has the format::

        "PROCESS:NAME":
            alphafold2: abc123
            python: 3.11.0

    Returns None if the file is absent or the key is not found.
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
        (k for k in rows[0].keys() if k.startswith('rank_')),
        key=lambda k: int(k.split('_', 1)[1]),
    )
    return {col: [float(row[col]) for row in rows] for col in rank_cols}


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

def build_modelcif(struct_files, plddt_file, name, prog, sw_version=None):
    """
    Build a modelcif.System from ranked structure files and a pLDDT TSV.

    Parameters
    ----------
    struct_files : list[str]
        Paths to PDB or mmCIF input structures, one per rank in rank order.
        Each file becomes a separate model in the output ModelGroup.
    plddt_file : str
        Path to *_plddt.tsv from extract_metrics.py.
    name : str
        Sample / sequence identifier used in titles and file naming.
    prog : str
        Prediction program key (see _SOFTWARE_INFO).
    sw_version : str, optional
        Version string parsed from the upstream versions.yml.

    Returns
    -------
    modelcif.System
    """
    biopy_structs = [_parse_structure(f) for f in struct_files]
    plddt_by_rank = _read_plddt_tsv(plddt_file)

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
            f'No standard polymer residues found in {struct_files[0]}. '
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

    software = modelcif.Software(
        name=sw_name,
        classification=sw_classification,
        description=f'{sw_name} structure prediction',
        location=sw_location,
        version=sw_version,  # None if not supplied; modelcif accepts this
    )
    system.software.append(software)

    # ---- pLDDT QA metric class ------------------------------------------
    class LocalPLDDT(modelcif.qa_metric.Local, modelcif.qa_metric.PLDDT):
        """Predicted lDDT-CA score in [0,100] output by the folding software"""

    LocalPLDDT.software = software

    # ---- One model per ranked structure ---------------------------------
    # Pair each struct file with the matching rank_N column from the TSV.
    # zip() stops at the shorter of the two, so a mismatch never raises.
    models = []
    for biopy_struct, (rank_key, plddt_values) in zip(
        biopy_structs, plddt_by_rank.items()
    ):
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
        plddt_iter = iter(plddt_values)
        for chain in bp_model_i:
            asym = asym_map.get(chain.id)
            if asym is None:
                continue
            seq_id = 1
            for res in chain.get_residues():
                if res.id[0] != ' ':
                    continue
                model.qa_metrics.append(
                    LocalPLDDT(asym.residue(seq_id), next(plddt_iter))
                )
                seq_id += 1

        models.append(model)

    model_group = modelcif.model.ModelGroup(models, name='All models')
    system.model_groups.append(model_group)

    # ---- Protocol -------------------------------------------------------
    protocol = modelcif.protocol.Protocol()
    step = modelcif.protocol.ModelingStep(
        input_data=modelcif.data.DataGroup([]),
        output_data=modelcif.data.DataGroup(models),
        name='Structure prediction',
        software=software,
    )
    protocol.steps.append(step)
    system.protocols.append(protocol)

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
    system = build_modelcif(args.structs, args.plddt, args.name, args.prog, sw_version)

    with open(output_file, open_mode) as fh:
        modelcif.dumper.write(fh, [system], format=fmt)

    print(f'Written: {output_file}', file=sys.stderr)


if __name__ == '__main__':
    main()
