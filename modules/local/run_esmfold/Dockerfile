ARG CUDA=11.7.1
FROM nvidia/cuda:${CUDA}-cudnn8-devel-ubuntu22.04 AS builder
# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA

LABEL authors="Athanasios Baltzis, Jose Espinosa-Carrasco" \
    title="nfcore/proteinfold_esmfold" \
    Version="1.2.0dev" \
    description="Docker image containing all software requirements to run ESMFold using the nf-core/proteinfold pipeline"

# Add env variables
ENV LD_LIBRARY_PATH="/conda/lib:/usr/local/cuda-11.7/lib64:/conda/lib/python3.9/site-packages/nvidia/cusparse/lib:$LD_LIBRARY_PATH" \
    PATH="/conda/bin:$PATH"

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A4B469963BF863CC
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda package manager
# Avoids using defaults channel
RUN wget -q -P /tmp "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" && \
    bash /tmp/Miniforge3-$(uname)-$(uname -m).sh -b -p /conda && \
    rm -rf /tmp/Miniforge3-$(uname)-$(uname -m).sh /var/lib/apt/lists/* && \
    apt-get autoremove -y && apt-get clean -y

RUN /conda/bin/conda install --quiet -y conda==24.11.1 pip python=3.9 \
    && conda clean --all --force-pkgs-dirs --yes

RUN    cd / && /conda/bin/conda update -qy conda \
    && /conda/bin/conda install -y -c conda-forge pip python

RUN    /conda/bin/pip install --no-cache-dir git+https://github.com/facebookresearch/esm.git
RUN    /conda/bin/pip install --no-cache-dir "fair-esm[esmfold]"
RUN /conda/bin/pip install --no-cache-dir torch==2.0.0 torchvision==0.15.0 --upgrade --force-reinstall --index-url https://download.pytorch.org/whl/cu118
RUN    /conda/bin/pip install --no-cache-dir \
    pytorch_lightning==1.9.5 \
    biopython==1.85 \
    ## https://github.com/facebookresearch/esm/issues/621#issuecomment-1741684707
    deepspeed==0.10.3 \
    dm-tree==0.1.8 \
    ml-collections==0.1.0 \
    numpy==1.23.5 \
    PyYAML==6.0.2 \
    requests==2.26.0 \
    scipy==1.13.1 \
    tqdm==4.62.2 \
    typing-extensions==4.12.2 \
    wandb==0.12.21

RUN    /conda/bin/pip install --no-cache-dir 'dllogger @ git+https://github.com/NVIDIA/dllogger.git'

## https://github.com/aqlaboratory/insilico_design_pipeline/blob/main/README.md#additional-notes
RUN git clone https://github.com/aqlaboratory/openfold.git && \
    cd openfold && \
    git checkout 4b41059694619831a7db195b7e0988fc4ff3a307 && \
    sed -i 's|deepspeed.utils.is_initialized|deepspeed.comm.comm.is_initialized|g' openfold/model/primitives.py && \
    /conda/bin/pip install . && \
    cd .. && rm -rf openfold

FROM nvidia/cuda:${CUDA}-cudnn8-devel-ubuntu22.04
# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA

COPY --from=builder /conda /conda

ENV LD_LIBRARY_PATH="/conda/lib:/usr/local/cuda-$(cut -f1,2 -d. <<< ${CUDA})/lib64:/conda/lib/python3.9/site-packages/nvidia/cusparse/lib:$LD_LIBRARY_PATH" \
    PATH="/conda/bin:$PATH"
