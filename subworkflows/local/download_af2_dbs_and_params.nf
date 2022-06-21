//
// Download all the required AlphaFold 2 databases and parameters
//
bfd            = 'https://storage.googleapis.com/alphafold-databases/casp14_versions/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz'
small_bfd      = 'https://storage.googleapis.com/alphafold-databases/reduced_dbs/bfd-first_non_consensus_sequences.fasta.gz'
af2_params     = 'https://storage.googleapis.com/alphafold/alphafold_params_2022-03-02.tar'
mgnify         = 'https://storage.googleapis.com/alphafold-databases/casp14_versions/mgy_clusters_2018_12.fa.gz'
pdb70          = 'http://wwwuser.gwdg.de/~compbiol/data/hhsuite/databases/hhsuite_dbs/old-releases/pdb70_from_mmcif_200916.tar.gz'
uniclust30     = 'https://storage.googleapis.com/alphafold-databases/casp14_versions/uniclust30_2018_08_hhsuite.tar.gz'
uniref90       = 'ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/uniref90.fasta.gz'
uniprot_sprot  = 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz'
uniprot_trembl = 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.fasta.gz'
pdb_mmCIF      = 'rsync.rcsb.org::ftp_data/structures/divided/mmCIF/'
pdb_obsolete   = 'ftp://ftp.wwpdb.org/pub/pdb/data/status/obsolete.dat'

include { ARIA2 as ARIA2_AF2_PARAMS     } from '../../modules/local/aria2.nf'
include { ARIA2 as ARIA2_BFD            } from '../../modules/local/aria2.nf'
include { ARIA2 as ARIA2_SMALL_BFD      } from '../../modules/local/aria2.nf'
include { ARIA2 as ARIA2_MGNIFY         } from '../../modules/local/aria2.nf'
include { ARIA2 as ARIA2_PDB70          } from '../../modules/local/aria2.nf'
include { ARIA2 as ARIA2_UNICLUST30     } from '../../modules/local/aria2.nf'
include { ARIA2 as ARIA2_UNIREF90       } from '../../modules/local/aria2.nf'
include { ARIA2 as ARIA2_UNIPROT_SPROT  } from '../../modules/local/aria2.nf'
include { ARIA2 as ARIA2_UNIPROT_TREMBL } from '../../modules/local/aria2.nf'
include { COMBINE_UNIPROT    } from '../../modules/local/combine_uniprot.nf'
include { DOWNLOAD_PDB_MMCIF } from '../../modules/local/download_pdb_mmcif.nf'


workflow DOWNLOAD_AF2_DBS_AND_PARAMS {
	take:
	db
	full_dbs

	main:
    ch_bfd = Channel.empty()
    download_path = Channel.empty()

    //Make a big if params.db else
    if (params.db) {
        if (full_dbs == true) {
            ch_bfd = file("${params.db}/bfd" )
        }
        else {
            ch_bfd = file( "${params.db}/small_bfd" )
        }

        ch_params     = file( "${params.db}/params" )
        ch_mgnify     = file( "${params.db}/mgnify" )
        ch_pdb70      = file( "${params.db}/pdb70" )
        ch_mmcif      = file( "${params.db}/pdb_mmcif" )
        ch_uniclust30 = file( "${params.db}/uniclust30" )
        ch_uniref90   = file( "${params.db}/uniref90" )
        ch_uniprot    = file( "${params.db}/uniprot" )
    } else {
        if (full_dbs == true) {
            ARIA2_BFD(
                bfd,
                'bfd'
            )
            ch_bfd =  ARIA2_BFD.out.db_path
        } else {
            ARIA2_SMALL_BFD(
                small_bfd,
                'small_bfd'
            )
            ch_bfd = ARIA2_SMALL_BFD.out.db_path
        }

        ARIA2_AF2_PARAMS(
            af2_params,
            'params'
        )
        ARIA2_MGNIFY(
            mgnify,
            'mgnify'
        )
        ARIA2_PDB70(
            pdb70,
            'pdb70'
        )
        DOWNLOAD_PDB_MMCIF(
            pdb_mmCIF,
            pdb_obsolete,
            'pdb_mmcif'
        )
        ARIA2_UNICLUST30(
            uniclust30,
            'uniclust30'
        )
        ARIA2_UNIREF90(
            uniref90,
            'uniref90'
        )
        ARIA2_UNIPROT_SPROT(
            uniprot_sprot,
            'uniprot_sprot'
        )
        ARIA2_UNIPROT_TREMBL(
            uniprot_trembl,
            'uniprot_trembl'
        )
        COMBINE_UNIPROT (
            ARIA2_UNIPROT_SPROT.out.db_path,
            ARIA2_UNIPROT_TREMBL.out.db_path,
            'uniprot'
        )
    }



    // if (full_dbs == true) {
    //     if (params.db) {
    //         ch_bfd = file("${params.db}/bfd" )
    //     }
    //     else {
    //         ARIA2_BFD(
    //             bfd,
    //             'bfd'
    //         )
    //         ch_bfd =  ARIA2_BFD.out.db_path
    //     }
    // }
    // else {
    //     if (params.db) {
    //         ch_bfd = file("${params.db}/small_bfd" )
    //     }
    //     else (params.db) {
    //         ARIA2_SMALL_BFD(
    //             small_bfd,
    //             'small_bfd'
    //         )
    //         ch_bfd = ARIA2_SMALL_BFD.out.db_path
    //     }

    // }

    // ARIA2_AF2_PARAMS(
    //     af2_params,
    //     'params'
    // )
    // ARIA2_MGNIFY(
    //     mgnify,
    //     'mgnify'
    // )
    // ARIA2_PDB70(
    //     pdb70,
    //     'pdb70'
    // )
    // DOWNLOAD_PDB_MMCIF(
    //     pdb_mmCIF,
    //     pdb_obsolete,
    //     'pdb_mmcif'
    // )
    // ARIA2_UNICLUST30(
    //     uniclust30,
    //     'uniclust30'
    // )
    // ARIA2_UNIREF90(
    //     uniref90,
    //     'uniref90'
    // )
    // ARIA2_UNIPROT_SPROT(
    //     uniprot_sprot,
    //     'uniprot_sprot'
    // )
    // ARIA2_UNIPROT_TREMBL(
    //     uniprot_trembl,
    //     'uniprot_trembl'
    // )
    // COMBINE_UNIPROT (
    //     ARIA2_UNIPROT_SPROT.out.db_path,
    //     ARIA2_UNIPROT_TREMBL.out.db_path,
    //     'uniprot'
    // )

    ch_bfd
        .concat (
            ARIA2_AF2_PARAMS.out.db_path,
            ARIA2_MGNIFY.out.db_path,
            ARIA2_PDB70.out.db_path,
            DOWNLOAD_PDB_MMCIF.out.db_path,
            ARIA2_UNICLUST30.out.db_path,
            ARIA2_UNIREF90.out.db_path,
            COMBINE_UNIPROT.out.db_path
        )
        .collect()
        .set {ch_db}

    // ch_bfd
    //     .combine (
    //         ARIA2_AF2_PARAMS.out.db_path)
    //     .combine (    ARIA2_MGNIFY.out.db_path)
    //     .combine (    ARIA2_PDB70.out.db_path)
    //     .combine (    DOWNLOAD_PDB_MMCIF.out.db_path)
    //     .combine (    ARIA2_UNICLUST30.out.db_path)
    //     .combine (    ARIA2_UNIREF90.out.db_path)
    //     .combine (    COMBINE_UNIPROT.out.db_path
    //     )
    //     .flatten()
    //     .first()
    //     .set {ch_db}

	emit:
	db = ch_db //    path: star/index/
}
