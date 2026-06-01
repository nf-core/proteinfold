ARG CUDA_VERSION=12.4.1
FROM nvidia/cuda:${CUDA_VERSION}-cudnn-runtime-ubuntu22.04
# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA_VERSION
ARG MINIFORGE_VERSION=24.11.3-0
ARG ESM_COMMIT=c94ed8d
ARG TRANSFORMERS_COMMIT=3a8956fb4d4ea16b0ec8e71deef2c2909b6a5cbf
ARG PYTHON_VERSION=3.12
ARG TORCH_VERSION=2.6.0

LABEL org.opencontainers.image.title="nf-core/proteinfold_esmfold2" \
    org.opencontainers.image.description="Docker image containing all software requirements to run ESMFold2 using the nf-core/proteinfold pipeline" \
    org.opencontainers.image.version="2.0.0" \
    org.opencontainers.image.authors="Joshua Storm Caley <j.caley@unsw.edu.au>" \
    org.opencontainers.image.source="https://github.com/nf-core/proteinfold" \
    org.opencontainers.image.licenses="MIT"

# Add env variables
ENV PATH="/conda/bin:$PATH"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda package manager
# Avoids using defaults channel
RUN wget -q -P /tmp \
    "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-$(uname)-$(uname -m).sh" && \
    bash /tmp/Miniforge3-$(uname)-$(uname -m).sh -b -p /conda && \
    rm -rf /tmp/Miniforge3-$(uname)-$(uname -m).sh /var/lib/apt/lists/* && \
    apt-get autoremove -y && apt-get clean -y

RUN /conda/bin/conda install --quiet -y -c conda-forge \
    conda=24.11.3 \
    pip \
    python=${PYTHON_VERSION} \
    biopython \
    rdkit \
    && /conda/bin/conda clean --all --force-pkgs-dirs --yes

RUN /conda/bin/pip install --no-cache-dir --upgrade pip setuptools wheel

RUN /conda/bin/pip install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cu124 \
    torch==${TORCH_VERSION}

RUN /conda/bin/pip install --no-cache-dir \
    "transformers @ git+https://github.com/Biohub/transformers.git@${TRANSFORMERS_COMMIT}" \
    "esm @ git+https://github.com/Biohub/esm.git@${ESM_COMMIT}"

WORKDIR /app

COPY bin/run_esmfold2.py /app/run_esmfold2.py
