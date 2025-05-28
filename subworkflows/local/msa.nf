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
        yaml: it[1].extension == "yaml"
        json: it[1].extension == "json"
    }
    .set{ch_input}

    ch_input.fasta
    .map{
        meta = it[0].clone();
        meta.cnt = getFastaSequences(it[1].text).size();
        [meta, it[1]]
    }
    .set{ch_input_full}

    if (true){
        def batch_itr = 0
        ch_input_full
        .map{it[1]}
        .unique()
        .map{"${it.baseName},${getFastaSequences(it.text)
                .collect { it.sequence }
                .join(':')}"
        }
        .buffer( size: mmseq_batch_size, remainder: true )
        .collectFile {
            batch_itr += 1;
            [ "input_seqs_${batch_itr}.csv", "id,sequence\n" + it.join("\n") + '\n' ]
        }
        .map{[["id": it.baseName], it]}
        .set {ch_input_seqs}

        ch_input_seqs.view()

        MMSEQS_COLABFOLDSEARCH (
            ch_input_seqs,
            ch_input_seqs.map{it[1]},
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
        ch_a3m.view()    
    }

    emit:
    input          = ch_input_full
    a3m            = ch_a3m
    versions       = ch_versions
}
/*
def getYamlSequences(yamlData) {
    @Grab('org.yaml:snakeyaml:2.0')
    import org.yaml.snakeyaml.Yaml
    def data = yaml.load(yaml_data)
    List<Map> enrichedEntries = []
    if (data?.sequences instanceof List) {
        enrichedEntries = data.sequences.collect { entry ->
            if (entry instanceof Map && entry.size() == 1) {
                def type = entry.keySet().first()
                def value = entry[type]
                if (value instanceof Map) {
                    def enriched = new LinkedHashMap(value)
                    enriched.type = type
                    return enriched
                }
            }
            return null
        }.findAll { it != null }
    }
    return enrichedEntries
}
*/
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