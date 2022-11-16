@@ -1,36 +0,0 @@
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Nextflow config file for running full-size tests
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Defines input files and everything required to run a full size pipeline test.

    Use as follows:
        nextflow run nf-core/proteinfold -profile test_full_colabfold_webserver,<docker/singularity> --outdir <OUTDIR>

----------------------------------------------------------------------------------------
*/

params {
    config_profile_name        = 'Full test profile for colabfold using colabfold server'
    config_profile_description = 'Minimal test dataset to check pipeline function'

    // Input data for full test of colabfold with Colabfold server
    mode             = 'colabfold'
    colabfold_server = 'webserver'
    colabfold_model  = 'AlphaFold2-ptm'
    input            = 'https://raw.githubusercontent.com/nf-core/test-datasets/proteinfold/testdata/samplesheet/v1.0/samplesheet.csv'
    // TODO: Add colabfold DB once it is available in AWS S3
    // colabfold_db     = "${projectDir}/assets/dummy_db_dir"
}
