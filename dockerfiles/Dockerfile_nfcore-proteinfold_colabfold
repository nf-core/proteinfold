FROM nvidia/cuda:12.6.2-cudnn-runtime-ubuntu24.04

LABEL authors="Athanasios Baltzis, Jose Espinosa-Carrasco, Leila Mansouri" \
    title="nfcore/proteinfold_colabfold" \
    Version="1.2.0dev" \
    description="Docker image containing all software requirements to run the COLABFOLD_BATCH module using the nf-core/proteinfold pipeline"

ENV PATH="/localcolabfold/colabfold-conda/bin:$PATH"
ENV LD_LIBRARY_PATH="/localcolabfold/colabfold-conda/lib:/usr/local/cuda/lib64"
ENV PYTHONPATH="/localcolabfold/colabfold-conda/lib"
ENV PATH="/MMseqs2/build/bin:$PATH"

# Use bash to support string substitution.
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A4B469963BF863CC
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    cuda-command-line-tools-12-6 \
    git \
    hmmer \
    kalign \
    tzdata \
    wget \
    curl \
    cmake \
    && rm -rf /var/lib/apt/lists/*

RUN cd / \
    && wget https://raw.githubusercontent.com/YoshitakaMo/localcolabfold/07e87ed/install_colabbatch_linux.sh \
    && sed -i "/colabfold.download/d" install_colabbatch_linux.sh \
    # Avoid error running on cpus
    # https://github.com/YoshitakaMo/localcolabfold/issues/238#issuecomment-2203777538
    && sed -i "/==0.4.28/d" install_colabbatch_linux.sh \
    && bash install_colabbatch_linux.sh

## Updated
RUN /localcolabfold/colabfold-conda/bin/python3.10 -m pip install tensorflow-cpu==2.17.0

# #Silence download of the AlphaFold2 params
RUN  sed -i "s|download_alphafold_params(|#download_alphafold_params(|g" /localcolabfold/colabfold-conda/lib/python3.10/site-packages/colabfold/batch.py
RUN  sed -i "s|if args\.num_models|#if args\.num_models|g" /localcolabfold/colabfold-conda/lib/python3.10/site-packages/colabfold/batch.py
