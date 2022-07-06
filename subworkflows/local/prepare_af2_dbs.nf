//
// Download all the required AlphaFold 2 databases and parameters
//
bfd            = 'https://storage.googleapis.com/alphafold-databases/casp14_versions/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz'
small_bfd      = 'https://storage.googleapis.com/alphafold-databases/reduced_dbs/bfd-first_non_consensus_sequences.fasta.gz'
af2_params     = 'https://storage.googleapis.com/alphafold/alphafold_params_2022-03-02.tar'
mgnify         = 'https://storage.googleapis.com/alphafold-databases/casp14_versions/mgy_clusters_2018_12.fa.gz'
pdb70          = 'http://wwwuser.gwdg.de/~compbiol/data/hhsuite/databases/hhsuite_dbs/old-releases/pdb70_from_mmcif_200916.tar.gz'
pdb_mmCIF      = 'rsync.rcsb.org::ftp_data/structures/divided/mmCIF/'
pdb_obsolete   = 'ftp://ftp.wwpdb.org/pub/pdb/data/status/obsolete.dat'
uniclust30     = 'https://storage.googleapis.com/alphafold-databases/casp14_versions/uniclust30_2018_08_hhsuite.tar.gz'
uniref90       = 'ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/uniref90.fasta.gz'
pdb_seqres     = 'ftp://ftp.wwpdb.org/pub/pdb/derived_data/pdb_seqres.txt'
uniprot_sprot  = 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz'
uniprot_trembl = 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.fasta.gz'

include {
    ARIA2_UNCOMPRESS as ARIA2_AF2_PARAMS
    ARIA2_UNCOMPRESS as ARIA2_BFD
    ARIA2_UNCOMPRESS as ARIA2_SMALL_BFD
    ARIA2_UNCOMPRESS as ARIA2_MGNIFY
    ARIA2_UNCOMPRESS as ARIA2_PDB70
    ARIA2_UNCOMPRESS as ARIA2_UNICLUST30
    ARIA2_UNCOMPRESS as ARIA2_UNIREF90
    ARIA2_UNCOMPRESS as ARIA2_UNIPROT_SPROT
    ARIA2_UNCOMPRESS as ARIA2_UNIPROT_TREMBL } from './aria2_uncompress'

include { ARIA2              } from '../../modules/local/aria2'
include { COMBINE_UNIPROT    } from '../../modules/local/combine_uniprot'
include { DOWNLOAD_PDBMMCIF } from '../../modules/local/download_pdbmmcif'

workflow PREPARE_AF2_DBS {
    main:
    ch_bfd        = Channel.empty()
    ch_bfd_small  = Channel.empty()

    if (params.af2_db) {
        if (params.full_dbs) {
            ch_bfd       = file("${params.af2_db}/bfd" )
            ch_bfd_small = file("${projectDir}/assets/dummy_db")
        }
        else {
            ch_bfd       = file("${projectDir}/assets/dummy_db")
            ch_bfd_small = file("${params.af2_db}/small_bfd")
        }

        // TODO parameters for each of the DBs that could be updated or provided in a user path
        // maybe have a db.config?
        // TODO add checkIfExists (need to create a fake structure for testing)
        ch_params     = file( "${params.af2_db}/params" )
        ch_mgnify     = file( "${params.af2_db}/mgnify" )
        ch_pdb70      = file( "${params.af2_db}/pdb70" )
        ch_mmcif      = file( "${params.af2_db}/pdb_mmcif" )
        ch_uniclust30 = file( "${params.af2_db}/uniclust30" )
        ch_uniref90   = file( "${params.af2_db}/uniref90" )
        ch_pdb_seqres = file( "${params.af2_db}/pdb_seqres" )
        ch_uniprot    = file( "${params.af2_db}/uniprot" )
    }
    else {
        if (params.full_dbs) {
            ARIA2_BFD(
                bfd
            )
            ch_bfd =  ARIA2_BFD.out.db
        } else {
            ARIA2_SMALL_BFD(
                small_bfd
            )
            ch_bfd_small = ARIA2_SMALL_BFD.out.db
        }

        ARIA2_AF2_PARAMS(
            af2_params
        )
        ch_params = ARIA2_AF2_PARAMS.out.db

        ARIA2_MGNIFY(
            mgnify
        )
        ch_mgnify = ARIA2_MGNIFY.out.db

        ARIA2_PDB70(
            pdb70
        )
        ch_pdb70 = ARIA2_PDB70.out.db

        DOWNLOAD_PDBMMCIF(
            pdb_mmCIF,
            pdb_obsolete
        )
        ch_mmcif = DOWNLOAD_PDBMMCIF.out.ch_db

        ARIA2_UNICLUST30(
            uniclust30
        )
        ch_uniclust30 = ARIA2_UNICLUST30.out.db

        ARIA2_UNIREF90(
            uniref90
        )
        ch_uniref90 = ARIA2_UNIREF90.out.db

        ARIA2 (
            pdb_seqres
        )
        ch_pdb_seqres = ARIA2.out.ch_db

        ARIA2_UNIPROT_SPROT(
            uniprot_sprot
        )
        ARIA2_UNIPROT_TREMBL(
            uniprot_trembl
        )
        COMBINE_UNIPROT (
            ARIA2_UNIPROT_SPROT.out.db,
            ARIA2_UNIPROT_TREMBL.out.db
        )
        ch_uniprot = COMBINE_UNIPROT.out.ch_db
    }

	emit:
    bfd        = ch_bfd
    bfd_small  = ch_bfd_small
    params     = ch_params
    mgnify     = ch_mgnify
    pdb70      = ch_pdb70
    pdb_mmcif  = ch_mmcif
    uniclust30 = ch_uniclust30
    uniref90   = ch_uniref90
    pdb_seqres = ch_pdb_seqres
    uniprot    = ch_uniprot
}
