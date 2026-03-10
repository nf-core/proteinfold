#!/usr/bin/env python
"""
Structure comparison utility for reproducibility testing.

Compares two predicted structures and reports RMSD deviation.
Used for CI/CD regression testing - ensuring structures are similar
across different random seeds or workflow changes.

No quality thresholds. Focus: structural consistency, not prediction quality.
"""

import argparse
import os
from pathlib import Path
import numpy as np
from Bio import PDB
import json


def get_ca_atoms(structure):
    """Extract CA (alpha carbon) atoms from a PDB structure."""
    ca_atoms = []
    for model in structure:
        for chain in model:
            for residue in chain:
                if 'CA' in residue:
                    ca_atoms.append(residue['CA'])
    return ca_atoms


def calculate_rmsd(atoms1, atoms2):
    """Calculate RMSD between two sets of atoms."""
    if len(atoms1) != len(atoms2):
        raise ValueError("Atom lists must have the same length")
    
    coords1 = np.array([atom.coord for atom in atoms1])
    coords2 = np.array([atom.coord for atom in atoms2])
    
    # Center coordinates
    coords1_centered = coords1 - np.mean(coords1, axis=0)
    coords2_centered = coords2 - np.mean(coords2, axis=0)
    
    # Calculate RMSD
    rmsd = np.sqrt(np.mean(np.sum((coords1_centered - coords2_centered)**2, axis=1)))
    return rmsd


def parse_plddt_file(plddt_file):
    """Parse pLDDT scores from TSV file."""
    scores = []
    with open(plddt_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    scores.append(float(line))
                except ValueError:
                    continue
    return np.array(scores) if scores else None


def compare_structures(pdb_file1, pdb_file2, rmsd_tolerance=2.0):
    """
    Compare two protein structures via RMSD.
    
    Args:
        pdb_file1: Path to reference PDB file
        pdb_file2: Path to comparison PDB file
        rmsd_tolerance: Maximum allowed RMSD in Angstroms (default: 2.0)
    
    Returns:
        dict: Comparison results including RMSD, pLDDT statistics, and deviation check
    """
    parser = PDB.PDBParser(QUIET=True)
    
    # Load structures
    structure1 = parser.get_structure("ref", pdb_file1)
    structure2 = parser.get_structure("pred", pdb_file2)
    
    # Get CA atoms
    ca1 = get_ca_atoms(structure1)
    ca2 = get_ca_atoms(structure2)
    
    if len(ca1) != len(ca2):
        raise ValueError(
            f"Structures have different number of CA atoms: {len(ca1)} vs {len(ca2)}"
        )
    
    if not ca1:
        raise ValueError("No CA atoms found in structures")
    
    # Calculate RMSD
    rmsd = calculate_rmsd(ca1, ca2)
    
    # Extract pLDDT from B-factors (for reference/debugging only, not for quality checks)
    plddt_scores_1 = []
    plddt_scores_2 = []
    
    for model in structure1:
        for chain in model:
            for residue in chain:
                if 'CA' in residue:
                    b_factor = residue['CA'].get_bfactor()
                    if b_factor > 0:
                        plddt_scores_1.append(b_factor)
    
    for model in structure2:
        for chain in model:
            for residue in chain:
                if 'CA' in residue:
                    b_factor = residue['CA'].get_bfactor()
                    if b_factor > 0:
                        plddt_scores_2.append(b_factor)
    
    # Calculate statistics for reporting
    results = {
        'pdb_file1': str(pdb_file1),
        'pdb_file2': str(pdb_file2),
        'rmsd': float(rmsd),
        'rmsd_tolerance': rmsd_tolerance,
        'rmsd_within_tolerance': rmsd <= rmsd_tolerance,
        'num_residues': len(ca1),
    }
    
    # Report pLDDT statistics (for debugging/monitoring, not for pass/fail)
    if plddt_scores_1:
        results['plddt_avg_ref'] = float(np.mean(plddt_scores_1) / 100.0)
        results['plddt_min_ref'] = float(np.min(plddt_scores_1) / 100.0)
        results['plddt_max_ref'] = float(np.max(plddt_scores_1) / 100.0)
    
    if plddt_scores_2:
        results['plddt_avg_pred'] = float(np.mean(plddt_scores_2) / 100.0)
        results['plddt_min_pred'] = float(np.min(plddt_scores_2) / 100.0)
        results['plddt_max_pred'] = float(np.max(plddt_scores_2) / 100.0)
    
    return results


def main():
    parser = argparse.ArgumentParser(
        description='Compare two protein structures for reproducibility testing'
    )
    
    parser.add_argument('pdb1', help='Reference PDB file')
    parser.add_argument('pdb2', help='Predicted PDB file')
    parser.add_argument(
        '--rmsd-tolerance', 
        type=float, 
        default=2.0,
        help='Maximum allowed RMSD in Angstroms for structures to be considered consistent (default: 2.0)'
    )
    parser.add_argument(
        '--output',
        help='Output JSON file for results'
    )
    
    args = parser.parse_args()
    
    results = compare_structures(
        args.pdb1, 
        args.pdb2,
        rmsd_tolerance=args.rmsd_tolerance
    )
    
    # Output results
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
    else:
        print(json.dumps(results, indent=2))
    
    # Return exit code 0 always (file comparison succeeded)
    return 0


if __name__ == '__main__':
    exit(main())
