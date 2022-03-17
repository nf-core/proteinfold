mkdir AlphaFold2-multimer-v2 && cd AlphaFold2-multimer-v2
wget https://storage.googleapis.com/alphafold/alphafold_params_colab_2022-03-02.tar \
  && tar -xvf alphafold_params_colab_2022-03-02.tar && rm *.tar
cd ../ && mkdir AlphaFold2-multimer-v1 && cd AlphaFold2-multimer-v1
wget https://storage.googleapis.com/alphafold/alphafold_params_colab_2021-10-27.tar \
  && tar -xvf alphafold_params_colab_2021-10-27.tar && rm *.tar
cd ../ && mkdir AlphaFold2-ptm && cd AlphaFold2-ptm
wget https://storage.googleapis.com/alphafold/alphafold_params_2021-07-14.tar \
  && tar -xvf alphafold_params_2021-07-14.tar && rm *.tar

