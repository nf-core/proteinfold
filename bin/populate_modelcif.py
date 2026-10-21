#!/usr/bin/env python3
"""Convert prediction structures and available quality metrics to ModelCIF."""

import argparse
import csv
import os
import re
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
        description='Convert prediction structures and available quality metrics to ModelCIF.'
    )
    parser.add_argument('--structs', required=True, nargs='+',
                        help='Input structure files (PDB or mmCIF), one per rank in rank order.')
    parser.add_argument('--msa',     required=True, help='*_msa.tsv from extract_metrics.py.')
    parser.add_argument('--plddt',   required=True, help='*_plddt.tsv from extract_metrics.py.')
    parser.add_argument('--pae',     required=True, nargs='+', help='Per-rank *_<rank>_pae.tsv files from extract_metrics.py, one per rank.')
    parser.add_argument('--pae-embed', action='store_true', help='Embed PAE as local-pairwise QA metrics in the primary modelCIF instead of as an associated file.')
    parser.add_argument('--ptm',     required=True, help='*_ptm.tsv from extract_metrics.py.')
    parser.add_argument('--iptm',    required=True, help='*_iptm.tsv from extract_metrics.py.')
    parser.add_argument('--name',    required=True)
    parser.add_argument('--prog',         required=True)
    parser.add_argument('--msa_tool',     default=None, help='MSA search tool used (e.g. jackhmmer, hhblits, mmseqs2). Embedded in the CoevolutionMSA protocol step.')
    parser.add_argument('--versions_yml', default=None, help='versions.yml emitted by the upstream run_* module.')
    parser.add_argument('--output',       default=None)
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
        (k for k in rows[0].keys() if k.startswith('rank_')),
        key=lambda k: int(k.split('_', 1)[1]),
    )
    return {col: [float(row[col]) for row in rows] for col in rank_cols}


def _read_ranked_score_tsv(tsv_file):
    scores = {}
    with open(tsv_file) as fh:
        for row in csv.reader(fh, delimiter='\t'):
            if not row or (len(row) == 1 and not row[0].strip()):
                continue
            if len(row) < 2:
                raise ValueError(f"Malformed row in {tsv_file}: {row!r}")
            rank, value = row[0].strip(), row[1].strip()
            if not rank or not value:
                raise ValueError(f"Empty rank or value in {tsv_file}: {row!r}")
            if not rank.startswith('rank_'):
                try:
                    rank = f"rank_{int(rank)}"
                except ValueError:
                    raise ValueError(f"Unrecognised rank label in {tsv_file}: {row!r}")
            try:
                scores[rank] = float(value)
            except ValueError:
                raise ValueError(f"Malformed score in {tsv_file}: {row!r}")
    return scores


def _rank_from_pae_filename(pae_file):
    match = re.search(r'(\d+)_pae\.tsv$', os.path.basename(pae_file))
    return int(match.group(1)) if match else None


def _map_pae_files_to_ranks(pae_files, num_structs):
    """Map PAE files to model ranks by filename, rejecting gaps, duplicates
    and unparseable names.  A single arbitrarily-named file (e.g. DUMMY_PAE.tsv)
    is accepted when there is exactly one model."""
    pae_by_rank = {}
    for pae_file in pae_files:
        rank = _rank_from_pae_filename(pae_file)
        if rank is None:
            if num_structs == 1 and len(pae_files) == 1:
                rank = 0
            else:
                raise ValueError(
                    f"Cannot infer model rank from PAE filename: {pae_file}; "
                    "expected '<name>_<rank>_pae.tsv'"
                )
        if rank in pae_by_rank:
            raise ValueError(
                f"Multiple PAE files map to rank {rank}: "
                f"{os.path.basename(pae_by_rank[rank])} and {os.path.basename(pae_file)}"
            )
        pae_by_rank[rank] = pae_file
    expected = set(range(num_structs))
    got = set(pae_by_rank)
    if got != expected:
        raise ValueError(
            f"PAE ranks {sorted(got)} do not match model ranks {sorted(expected)}; "
            f"missing: {sorted(expected - got)}, unexpected: {sorted(got - expected)}"
        )
    return pae_by_rank


def _check_ranked_scores(scores, struct_ranks, label, tsv_file):
    """Explicit missing-scores policy: an empty file means the metric is
    absent for every rank (e.g. monomer runs without ipTM); a partially
    populated file is a rank mismatch and is an error."""
    if not scores:
        print(
            f'No {label} scores found in {tsv_file}; '
            f'omitting {label} QA metrics from all models',
            file=sys.stderr,
        )
        return False
    missing = set(struct_ranks) - set(scores)
    extra = set(scores) - set(struct_ranks)
    if missing or extra:
        raise ValueError(
            f"{label} ranks in {tsv_file} do not match structure ranks; "
            f"missing: {sorted(missing)}, unexpected: {sorted(extra)}"
        )
    return True


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
    pae_files,
    ptm_file,
    iptm_file,
    name,
    prog,
    sw_version=None,
    msa_tool=None,
    pae_embed=False,
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
    pae_files : list[str]
        Paths to per-rank *_<rank>_pae.tsv files from extract_metrics.py.
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
    pae_embed : bool, optional
        If True, embed PAE values as local-pairwise QA metrics.

    Returns
    -------
    modelcif.System
    """
    biopy_structs = [_parse_structure(f) for f in struct_files]
    plddt_by_rank = _read_plddt_tsv(plddt_file)
    if len(biopy_structs) != len(plddt_by_rank):
        raise ValueError(
            f'Expected one pLDDT rank per structure: got {len(biopy_structs)} '
            f'structures and {len(plddt_by_rank)} ranks'
        )
    struct_ranks = list(plddt_by_rank.keys())
    pae_by_rank = _map_pae_files_to_ranks(pae_files, len(biopy_structs))
    pae_matrices = (
        {rank: _read_pae_tsv(f) for rank, f in pae_by_rank.items()}
        if pae_embed else None
    )
    ptm_by_rank = _read_ptm_tsv(ptm_file)
    iptm_by_rank = _read_iptm_tsv(iptm_file)
    has_ptm = _check_ranked_scores(ptm_by_rank, struct_ranks, 'pTM', ptm_file)
    has_iptm = _check_ranked_scores(iptm_by_rank, struct_ranks, 'ipTM', iptm_file)
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
    # Pair each struct file with the matching rank_N column from the TSV.
    models = []
    for biopy_struct, (rank_key, plddt_values) in zip(
        biopy_structs, plddt_by_rank.items()
    ):
        bp_model_i = next(biopy_struct.get_models())
        residue_count = sum(
            1 for chain in bp_model_i for res in chain if res.id[0] == ' '
        )
        if len(plddt_values) != residue_count:
            raise ValueError(f'{rank_key}: expected {residue_count} pLDDT values, got {len(plddt_values)}')
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
            pae_matrix = pae_matrices[int(rank_key.split('_', 1)[1])]
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

        if has_ptm:
            model.qa_metrics.append(GlobalPTM(ptm_by_rank[rank_key]))
        if has_iptm:
            model.qa_metrics.append(GlobalIpTM(iptm_by_rank[rank_key]))

        models.append(model)

    # So model.ModelGroup is great here since every single inference from a multi-model method (e.g. AlphaFold)
    # is captured coordinates-wise as a separate structure to inspect, but the protocol and software metadata is shared across them.
    model_group = modelcif.model.ModelGroup(models, name='All models')
    system.model_groups.append(model_group)

    # ---- Protocol -------------------------------------------------------
    protocol = modelcif.protocol.Protocol()

    msa_data = modelcif.data.Data(
        'Coevolution MSA',
        details=f'{msa_num_seqs} sequences, {msa_length} columns',
    )
    system.data.append(msa_data)
    msa_step = modelcif.protocol.CoevolutionMSAStep(
        input_data=modelcif.data.DataGroup(list(seen_seqs.values())),
        output_data=msa_data,
        name=msa_tool,
        software=software,
    )
    protocol.steps.append(msa_step)

    # Modeling step: MSA is the input; ranked models are the output.
    step = modelcif.protocol.ModelingStep(
        input_data=msa_data,
        output_data=modelcif.data.DataGroup(models),
        name='Structure prediction',
        software=software,
    )
    protocol.steps.append(step)
    system.protocols.append(protocol)

    if not pae_embed:
        associated_files = []
        for rank in sorted(pae_by_rank):
            pae_data = modelcif.data.Data(
                f'Predicted aligned error matrix (rank_{rank})',
                details='Predicted aligned error (PAE) values for this rank, exported as TSV by extract_metrics.py',
            )
            system.data.append(pae_data)
            associated_files.append(
                modelcif.associated.File(
                    path=os.path.join('pae', os.path.basename(pae_by_rank[rank])),
                    details=f'Predicted aligned error (PAE) matrix for rank_{rank}',
                    data=pae_data,
                )
            )
        system.repositories.append(
            modelcif.associated.Repository(url_root=None, files=associated_files)
        )

    return system


def main(args=None):
    args = parse_args(args)

    output_file = args.output or f'{args.name}_{args.prog}.mmcif'

    sw_version = _read_sw_version(args.versions_yml, args.prog)
    # Nextflow emits the string 'None' when no msa_tool is known; normalise to Python None.
    msa_tool = None if args.msa_tool in (None, 'None') else args.msa_tool
    system = build_modelcif(
        args.structs,
        args.plddt,
        args.msa,
        args.pae,
        args.ptm,
        args.iptm,
        args.name,
        args.prog,
        sw_version,
        msa_tool,
        args.pae_embed,
    )

    with open(output_file, 'w') as fh:
        modelcif.dumper.write(fh, [system])

    print(f'Written: {output_file}', file=sys.stderr)


if __name__ == '__main__':
    main()
