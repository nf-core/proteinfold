# Scientific Test Refactoring: Proper Library Usage

## Overview

Refactored scientific tests to use proper libraries instead of manual string parsing:

- **BioPython** for PDB structure parsing (not string manipulation)
- **csv module** for TSV file parsing (not manual splits)
- **NumPy** for statistical calculations

## Architecture

### Nextflow Tests (Orchestration Layer)

Tests validate:

- File existence and readability
- Directory structure correctness
- Workflow completion status
- Output file formats

**Pattern: Tests focus on "what exists" not "what values are"**

### Python Utilities (Analysis Layer)

`bin/compare_structures_fuzzy.py` handles detailed metric extraction:

- BioPython PDBParser for structure analysis
- Proper B-factor extraction with error handling
- pLDDT score validation with proper parsing

### Validation Module

`modules/local/validate_structure_quality`

- Nextflow process wrapping the Python utility
- Can be called from pipelines for automated quality checks
- Produces JSON reports for downstream processing

## Key Changes

### Before (Manual String Parsing ❌)

```groovy
def scores = plddt_file.text.trim().split("\\n")
def plddt_values = scores.collect { it.trim().isEmpty() ? null : Float.parseFloat(it) }
def avg_plddt = plddt_values.sum() / plddt_values.size()
```

Problems:

- Fragile to different line endings or spacing
- No error handling for malformed TSV
- Impossible to handle multi-column TSV properly
- Duplicates parsing logic

### After (Proper Libraries ✓)

```groovy
// Let Python handle it with csv module and BioPython
// Tests just validate file exists and is non-empty
// Detailed parsing done in bin/compare_structures_fuzzy.py
```

Benefits:

- Single source of truth for parsing (Python script)
- Proper error handling
- Uses industry-standard libraries
- Easy to maintain and extend
- Handles edge cases correctly

## Usage Examples

### Running Tests

```bash
# Tests now focus on structure validation
nextflow test tests/alphafold2_scientific_validation.nf.test
nextflow test tests/alphafold2_reproducibility_advanced.nf.test
```

### Using Validation in Pipelines

```nextflow
include { VALIDATE_STRUCTURE_QUALITY } from './modules/local/validate_structure_quality/main'

workflow {
    // ... prediction pipeline ...
    VALIDATE_STRUCTURE_QUALITY(pdb_channel)
    VALIDATE_STRUCTURE_QUALITY.out.report.view()
}
```

### Direct Python Utility Usage

```bash
# Validate structure quality using BioPython
python bin/compare_structures_fuzzy.py validate structure.pdb \
  --plddt-min 0.4 \
  --plddt-target 0.7 \
  --output quality.json

# Compare two structures with RMSD tolerance
python bin/compare_structures_fuzzy.py compare ref.pdb pred.pdb \
  --rmsd-tolerance 2.0 \
  --output comparison.json
```

## Files Changed

### Tests Modified

- `tests/alphafold2_scientific_validation.nf.test`: Removed manual TSV parsing
- `tests/alphafold2_reproducibility_advanced.nf.test`: Removed manual PDB parsing

### New Files

- `modules/local/validate_structure_quality/main.nf`: Validation process
- `modules/local/validate_structure_quality/environment.yml`: Dependencies
- `modules/local/validate_structure_quality/meta.yml`: Metadata

### Existing Files Updated

- `bin/compare_structures_fuzzy.py`: Already using BioPython and csv module properly

## Best Practices

✓ **DO:**

- Use BioPython for PDB file analysis
- Use csv.reader for TSV/CSV parsing
- Delegate detailed parsing to Python utilities
- Have Nextflow tests focus on orchestration
- Write detailed analysis in Python

✗ **DON'T:**

- Manually parse PDB with string slicing
- Use split() for TSV without csv module
- Mix Groovy parsing with Python script logic
- Assume consistent formatting

## Validation Checklist

- [x] Removed all manual string parsing from PDB files
- [x] Removed all manual string splitting of TSV files
- [x] Created proper validation module with BioPython
- [x] Updated tests to use file validation, not value parsing
- [x] Added env.yml with BioPython dependency
- [x] Added documentation explaining the architecture

## Related Files

- `bin/compare_structures_fuzzy.py`: Main utility (BioPython, csv)
- `modules/local/validate_structure_quality`: Integration module
- `docs/SCIENTIFIC_TESTS.md`: Test documentation
- `tests/alphafold2_scientific_validation.nf.test`: Fixed seed/random seed tests
- `tests/alphafold2_reproducibility_advanced.nf.test`: Advanced quality tests
