ARG CUDA=12.2.2
FROM nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu20.04
# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA

LABEL authors="Luisa Santus, Athanasios Baltzis, Jose Espinosa-Carrasco, Leila Mansouri" \
    title="nfcore/proteinfold_alphafold2_msa" \
    Version="1.2.0dev" \
    description="Docker image containing all software requirements to run the RUN_ALPHAFOLD2_MSA module using the nf-core/proteinfold pipeline"

# Use bash to support string substitution.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Add env variables
ENV LD_LIBRARY_PATH="/usr/local/cuda-$(cut -f1,2 -d. <<< ${CUDA})/lib64:$LD_LIBRARY_PATH"
ENV PATH="/opt/conda/bin:$PATH"

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A4B469963BF863CC
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    build-essential \
    cmake \
    cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA//./-}) \
    git \
    hmmer \
    kalign \
    tzdata \
    wget \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y \
    && apt-get clean

# Clone AlphaFold2
RUN git clone https://github.com/cbcrg/alphafold.git /app/alphafold && \
    cd /app/alphafold && \
    git checkout 1b3170e9409472ec8ad044f9935c92bedd7b4674 && \
    cd -

# Compile HHsuite from source
RUN git clone --branch v3.3.0 --single-branch https://github.com/soedinglab/hh-suite.git /tmp/hh-suite \
    && mkdir /tmp/hh-suite/build \
    && cd /tmp/hh-suite/build \
    && cmake -DCMAKE_INSTALL_PREFIX=/opt/hhsuite .. \
    && make -j 4 && make install \
    && ln -s /opt/hhsuite/bin/* /usr/bin \
    && cd - && rm -rf /tmp/hh-suite

# Install Miniforge package manager
RUN wget -q -P /tmp \
    "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" \
    && bash /tmp/Miniforge3-$(uname)-$(uname -m).sh -b -p /opt/conda \
    && rm /tmp/Miniforge3-$(uname)-$(uname -m).sh

# Install conda packages
RUN conda install --quiet --yes --channel conda-forge \
    pip \
    python=3.11 \
    && conda clean --all --force-pkgs-dirs --yes

# Install pip packages
RUN pip3 install --upgrade pip --no-cache-dir \
    # && pip3 install -r /app/alphafold/requirements_msa.txt --no-cache-dir \
    && pip3 install --no-cache-dir \
        absl-py==1.0.0 \
        biopython==1.79 \
        dm-tree==0.1.8 \
        numpy==1.24.3 \
        pandas==2.0.3 \
        scipy==1.11.1

# We need to run `ldconfig` first to ensure GPUs are visible, due to some quirk
# with Debian. See https://github.com/NVIDIA/nvidia-docker/issues/1399 for
# details.
# ENTRYPOINT does not support easily running multiple commands, so instead we
# write a shell script to wrap them up.
WORKDIR /app/alphafold
RUN echo $'#!/bin/bash\n\
python /app/alphafold/run_alphafold.py "$@"' > /app/run_alphafold.sh \
    && chmod +x /app/run_alphafold.sh
ENTRYPOINT ["/app/run_alphafold.sh"]
