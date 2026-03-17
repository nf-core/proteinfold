/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Base Output Validation Helpers for nf-test
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Reusable validation functions for all structure prediction modes.
    Each mode validates the same core outputs (TSV metrics, PDB files),
    but can extend with mode-specific assertions.

    To use in a test file, copy these helper methods into your .nf.test file
    or source this file. Methods are static for compatibility with nf-test.

    Example:
        assert validateModeMetrics(params.outdir, 'alphafold2')
        def results = getMetricsOutput(params.outdir)
*/

// Helper: Validate core metrics existence and format
def validateModeMetrics(String outdir, String mode) {
    def plddt_files = file("${outdir}/*/*/*plddt.tsv")
    def msa_files = file("${outdir}/*/*/*msa.tsv")

    if (plddt_files.isEmpty()) {
        throw new AssertionError("No pLDDT TSV files found in ${outdir}")
    }
    if (msa_files.isEmpty()) {
        throw new AssertionError("No MSA TSV files found in ${outdir}")
    }

    // Validate content is not empty
    plddt_files.each { f ->
        if (f.text.strip().isEmpty()) {
            throw new AssertionError("Empty pLDDT file: ${f.name}")
        }
    }

    msa_files.each { f ->
        if (f.text.strip().isEmpty()) {
            throw new AssertionError("Empty MSA file: ${f.name}")
        }
    }

    return true
}

// Helper: Validate PDB/CIF structure files
def validateModeStructures(String outdir, String structureSuffix = '.pdb') {
    def struct_files = file("${outdir}/**/*${structureSuffix}")

    if (struct_files.isEmpty()) {
        throw new AssertionError("No structure files (${structureSuffix}) found in ${outdir}")
    }

    struct_files.each { f ->
        def content = f.text
        if (content.isEmpty()) {
            throw new AssertionError("Empty structure file: ${f.name}")
        }

        // Basic validation
        if (structureSuffix == '.pdb' && !content.contains("ATOM")) {
            throw new AssertionError("No ATOM records in PDB: ${f.name}")
        }
    }

    return struct_files.size()
}

// Helper: Get all metrics TSV files for snapshot comparison
def getMetricsOutput(String outdir) {
    def plddt = file("${outdir}/*/*/*plddt.tsv").collect { it.name }
    def msa = file("${outdir}/*/*/*msa.tsv").collect { it.name }
    def pae = file("${outdir}/*/*/*pae*.tsv").collect { it.name }

    return [
        plddt_count: plddt.size(),
        msa_count: msa.size(),
        pae_count: pae.size(),
        plddt_names: plddt.sort(),
        msa_names: msa.sort(),
        pae_names: pae.sort()
    ]
}

// Helper: Get mode-specific output structure
def getModeOutputStructure(String outdir, String mode, String variant = null) {
    String modeDir = variant ? "${outdir}/${mode}/${variant}" : "${outdir}/${mode}"
    def dir = file(modeDir)

    if (!dir.exists()) {
        throw new AssertionError("Mode directory not found: ${modeDir}")
    }

    def proteins = dir.listFiles().findAll { it.isDirectory() }
    return [
        exists: true,
        protein_count: proteins.size(),
        proteins: proteins.collect { it.name }.sort(),
        file_count: file("${modeDir}/**/*").flatten().count { it.isFile() }
    ]
}

// Helper: Validate PAE outputs (optional, for multimer modes)
def validatePAEOutput(String outdir) {
    def pae_files = file("${outdir}/*/*/*pae*.tsv")
    if (pae_files.isEmpty()) {
        return [exists: false, count: 0]
    }

    pae_files.each { f ->
        if (f.text.isEmpty()) {
            throw new AssertionError("Empty PAE file: ${f.name}")
        }
    }

    return [exists: true, count: pae_files.size()]
}
