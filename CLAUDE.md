# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **nf-core/proteinfold**, a bioinformatics pipeline for protein 3D structure prediction built with Nextflow. It supports multiple protein folding algorithms including AlphaFold2, AlphaFold3, ColabFold, ESMFold, RoseTTAFold-All-Atom, HelixFold3, and Boltz-1.

## Common Development Commands

### Testing
```bash
# Run basic test with Docker
nextflow run . -profile debug,test,docker --outdir results

# Run specific protein folding method tests
nextflow run . -profile test_alphafold2_split,docker --outdir results
nextflow run . -profile test_colabfold_local,docker --outdir results
nextflow run . -profile test_esmfold,docker --outdir results

# Run with nf-test
nf-test test
nf-test test tests/workflows/<specific_workflow>.nf.test
```

### Linting and Validation
```bash
# Lint pipeline with nf-core tools
nf-core pipelines lint .

# Validate parameters schema
nf-core pipelines schema build
nf-core pipelines schema validate
```

### Development Mode
```bash
# Run in development/debug mode
nextflow run . -profile debug,test,docker --outdir results

# Skip specific processes during development
nextflow run . -profile test,docker --skip_multiqc --skip_visualisation --outdir results
```

## Architecture Overview

### Main Workflow Structure
- **Entry point**: `main.nf` - orchestrates the entire pipeline
- **Subworkflows**: Database preparation workflows in `subworkflows/local/prepare_*_dbs.nf`
- **Workflows**: Algorithm-specific workflows in `workflows/` (alphafold2.nf, colabfold.nf, etc.)
- **Modules**: Reusable process definitions in `modules/local/` and `modules/nf-core/`

### Pipeline Flow
1. **PIPELINE_INITIALISATION** - validates parameters and reads input samplesheet
2. **Database Preparation** - downloads/prepares required databases for each algorithm
3. **Algorithm-Specific Workflows** - runs the selected protein folding algorithm(s)
4. **POST_PROCESSING** - generates visualization reports and MultiQC reports
5. **PIPELINE_COMPLETION** - handles email notifications and cleanup

### Configuration System
- **Main config**: `nextflow.config` - contains all parameters and profile definitions
- **Mode-specific configs**: `conf/modules_*.config` files for algorithm-specific settings
- **Test profiles**: Multiple test configurations in `conf/test*.config`
- **Database links**: `conf/dbs.config` - contains download URLs for databases

### Key Parameters
- `--mode` - selects algorithm(s): alphafold2, alphafold3, colabfold, esmfold, etc.
- `--input` - path to samplesheet CSV
- `--outdir` - output directory
- `--use_gpu` - enables GPU acceleration
- `--*_db` - paths to pre-downloaded databases (optional)
- `--*_full_dbs` - use full vs reduced databases (where applicable)

### Database Management
Each algorithm has its own database preparation subworkflow:
- Checks if databases exist locally via `--*_db_path` parameters
- If not provided, downloads from URLs defined in `conf/dbs.config`
- Handles both full and reduced database versions
- Creates standardized database channel outputs for workflows

### Module Organization
- **nf-core modules**: Standardized, community-maintained modules from nf-core/modules
- **Local modules**: Custom modules specific to this pipeline in `modules/local/`
- **Process labels**: Used for resource allocation (e.g., `process_single`, `process_high`)

### Testing Strategy
- **Stub runs**: Fast tests using mocked processes (`stubRun = true`)
- **Small datasets**: Minimal test data for CI/CD
- **Full-size tests**: Run on AWS with real datasets
- **Algorithm-specific tests**: Each folding method has dedicated test profiles

### Development Patterns
- Parameters are mode-conditional (only loaded if algorithm is selected)
- Database preparation is separated from algorithm execution
- Channels are carefully managed to handle optional databases
- GPU support is configurable per-profile
- Resource requirements scale with process complexity

### MultiQC Integration
- Collects outputs from all enabled algorithms
- Custom MultiQC config at `assets/multiqc_config.yml`
- Generates unified reports across multiple folding methods

When adding new features:
1. Update `nextflow_schema.json` for new parameters
2. Add appropriate test profiles in `conf/`
3. Consider resource requirements in `conf/base.config`
4. Update documentation in `docs/`
5. Ensure proper channel handling for optional components