FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

LABEL Author="j.caley@unsw.edu.au" \
    title="nfcore/proteinfold_helixfold3" \
    Version="0.9.0" \
    description="Docker image containing all software requirements to run the RUN_HELIXFOLD3 module using the nf-core/proteinfold pipeline"

ENV PYTHONPATH="/app/helixfold3:$PYTHONPATH" \
    PATH="/conda/bin:/app/helixfold3:$PATH" \
    PYTHON_BIN="/conda/envs/helixfold/bin/python3.9" \
    ENV_BIN="/conda/envs/helixfold/bin" \
    OBABEL_BIN="/conda/envs/helixfold/bin"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y wget git && \
    wget -q -P /tmp "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" && \
    bash /tmp/Miniforge3-$(uname)-$(uname -m).sh -b -p /conda && \
    rm -rf /tmp/Miniforge3-$(uname)-$(uname -m).sh /var/lib/apt/lists/* && \
    apt-get autoremove -y && apt-get clean -y

RUN git clone --single-branch --branch dev --depth 1 --no-checkout https://github.com/PaddlePaddle/PaddleHelix.git /app/helixfold3 && \
    cd /app/helixfold3 && \
    git sparse-checkout init --cone && \
    git sparse-checkout set apps/protein_folding/helixfold3 && \
    git checkout dev && \
    mv apps/protein_folding/helixfold3/* . && \
    rm -rf apps

COPY environment_nfcore-proteinfold_helixfold3.yaml /app/helixfold3/
RUN /conda/bin/mamba env create --file=/app/helixfold3/environment_nfcore-proteinfold_helixfold3.yaml && \
    /conda/bin/mamba install -y -c bioconda aria2 hmmer==3.3.2 kalign2==2.04 hhsuite==3.3.0 -n helixfold && \
    /conda/bin/mamba install -y -c conda-forge openbabel -n helixfold && \
    /conda/bin/mamba clean --all --force-pkgs-dirs -y && \
    rm -rf /root/.cache && \
    apt-get autoremove -y && apt-get remove --purge -y wget git && apt-get clean -y
