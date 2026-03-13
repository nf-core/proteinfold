//
// Post processing analysis for the predicted structures
//

//
// SUBWORKFLOW: Consisting entirely of nf-core/modules
//
include { MMSEQS_COLABFOLDSEARCH } from '../../modules/local/mmseqs_colabfoldsearch'

workflow MSA {

    take:
    ch_samplesheet
    ch_colabfold_db        // channel: path(colabfold_db)
    ch_uniref30            // channel: path(uniref30)
    mmseq_batch_size

    main:
    ch_versions = Channel.empty()
    ch_a3m      = Channel.empty()

    ch_samplesheet
    .branch {
        fasta: it[1].extension == "fasta" || it[1].extension == "fa"
        yaml: it[1].extension == "yaml" || it[1].extension == ".yml"
        json: it[1].extension == "json"
    }
    .set{ch_input}

    ch_input.fasta
    .map{
        meta = it[0].clone();
        meta.cnt = getFastaSequences(it[1].text).size();
        [meta, it[1]]
    }
    .set{ch_input_fasta}

    ch_input.yaml
    .map {
        meta = it[0].clone();
        meta.cnt = getYamlSequences(it[1].text).size();
        [meta, it[1]]
    }
    .set { ch_input_yaml }

    ch_input_full = ch_input_fasta.mix(ch_input_yaml)

    def batch_itr = 0
    ch_input_full
    .map{it[1]}
    .unique()
    .map {
        def sequences = it.name.endsWith(".yaml") || it.name.endsWith(".yml")
            ? getYamlSequences(it.text)
            : getFastaSequences(it.text)

        "${it.baseName},${sequences.collect { it.sequence }.join(':')}"
    }
    .buffer( size: mmseq_batch_size, remainder: true )
    .collectFile {
        batch_itr += 1;
        [ "input_seqs_${batch_itr}.csv", "id,sequence\n" + it.join("\n") + '\n' ]
    }
    .map{[["id": it.baseName], it]}
    .set {ch_input_seqs}

    MMSEQS_COLABFOLDSEARCH (
        ch_input_seqs,
        ch_colabfold_db,
        ch_uniref30
    )
    ch_versions = ch_versions.mix(MMSEQS_COLABFOLDSEARCH.out.versions)

    ch_a3m = ch_a3m.mix(
        ch_input_full
        .map{[it[1].baseName, it[0]]}
        .combine(
            MMSEQS_COLABFOLDSEARCH.out.a3m
            .map{it[1]}
            .flatten()
            .map {[it.baseName, it]},
            by:0
        )
        .map{[it[1], it[2]]}
    )

    emit:
    formated_input          = ch_input_full
    a3m            = ch_a3m
    versions       = ch_versions
}

def getYamlSequences(yamlData) {
    List<Map> enrichedEntries = []
    Map currentEntry = [:]
    inSequences = false
    yamlData.split("\n").each { line ->
        def trimmed = line.trim()

        // Detect start of sequences section
        if (trimmed == 'sequences:') {
            inSequences = true
            return
        }
        if (inSequences && !line.startsWith('  ') && !trimmed.isEmpty()) {
            inSequences = false
            return
        }
        if (!inSequences){
            return
        }


        if (trimmed.startsWith('-') && trimmed.endsWith(':')) {
            if (!currentEntry.isEmpty()) {
                enrichedEntries << currentEntry
            }
            currentEntry = ['type': trimmed[1..-2]]
        }else{
            def (key, value) = trimmed.split(':', 2)*.trim()
            currentEntry[key] = value
        }
    }
    if (!currentEntry.isEmpty()) {
        enrichedEntries << currentEntry
    }
    return enrichedEntries
}

def getFastaSequences(fastaData) {
    List<Map> fastaEntries = []
    String currentId = null
    StringBuilder currentSeq = new StringBuilder()

    fastaData.split("\n").each { line ->
        if (line.startsWith(">")) {
            if (currentId) {
                fastaEntries << [id: currentId, sequence: currentSeq.toString()]
            }
            currentId = line[1..-1].trim()  // Remove '>' and trim
            currentSeq = new StringBuilder()
        } else {
            currentSeq.append(line.trim())
        }
    }

    if (currentId) {
        fastaEntries << [id: currentId, sequence: currentSeq.toString()]
    }

    return fastaEntries
}
