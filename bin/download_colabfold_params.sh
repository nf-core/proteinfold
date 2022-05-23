set -e

if [[ $# -eq 0 ]]; then
    echo "Error: download directory must be provided as an input argument."
    exit 1
fi

DOWNLOAD_DIR="$1"

mkdir -p "$DOWNLOAD_DIR"/AlphaFold2-multimer-v2/params && cd "$DOWNLOAD_DIR"/AlphaFold2-multimer-v2/params
wget https://storage.googleapis.com/alphafold/alphafold_params_colab_2022-03-02.tar \
    && tar -xvf alphafold_params_colab_2022-03-02.tar && rm *.tar
cd ../../ && mkdir -p AlphaFold2-multimer-v1/params && cd AlphaFold2-multimer-v1/params
wget https://storage.googleapis.com/alphafold/alphafold_params_colab_2021-10-27.tar \
    && tar -xvf alphafold_params_colab_2021-10-27.tar && rm *.tar
cd ../../ && mkdir -p AlphaFold2-ptm/params && cd AlphaFold2-ptm/params
wget https://storage.googleapis.com/alphafold/alphafold_params_2021-07-14.tar \
    && tar -xvf alphafold_params_2021-07-14.tar && rm *.tar

