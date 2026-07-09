#docker buildx build   --platform linux/amd64   -t icrsc/proteinfold_alphafold3_b1f7802:2.0.0   --push   .
FROM nvidia/cuda:12.6.3-base-ubuntu24.04

LABEL org.opencontainers.image.title="nf-core/proteinfold_alphafold3" \
      org.opencontainers.image.description="AlphaFold3 container adapted from the DeepMind Dockerfile for Nextflow/nf-core proteifold usage" \
      org.opencontainers.image.version="2.0.0-deepmind-nextflow" \
      org.opencontainers.image.source="https://github.com/google-deepmind/alphafold3" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV DEBIAN_FRONTEND=noninteractive

# System packages required for AlphaFold3, HMMER, and Nextflow task scripts.
RUN apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        curl \
        findutils \
        gawk \
        git \
        grep \
        gzip \
        jq \
        less \
        make \
        patch \
        procps \
        sed \
        tar \
        unzip \
        wget \
        xz-utils \
        zlib1g-dev \
        zstd \
        gcc \
        g++ \
        python3.12 \
        python3.12-dev \
    && rm -rf /var/lib/apt/lists/*

# Install uv, pinned for reproducibility.
COPY --from=ghcr.io/astral-sh/uv:0.9.24 /uv /uvx /bin/

ENV UV_COMPILE_BYTECODE=1
ENV UV_PROJECT_ENVIRONMENT=/alphafold3_venv

RUN uv venv "${UV_PROJECT_ENVIRONMENT}"

ENV PATH="/hmmer/bin:/alphafold3_venv/bin:/usr/local/bin:$PATH"

# Clone AlphaFold3 source code.
# Optional: pin this to a specific commit for reproducibility.
ARG ALPHAFOLD3_REPO="https://github.com/google-deepmind/alphafold3.git"
ARG ALPHAFOLD3_REF="main"

RUN git clone "${ALPHAFOLD3_REPO}" /app/alphafold \
    && cd /app/alphafold \
    && git checkout "${ALPHAFOLD3_REF}"

# Install HMMER 3.4 with the DeepMind sequence-limit patch.
RUN mkdir /hmmer_build /hmmer \
    && wget http://eddylab.org/software/hmmer/hmmer-3.4.tar.gz --directory-prefix /hmmer_build \
    && cd /hmmer_build \
    && echo "ca70d94fd0cf271bd7063423aabb116d42de533117343a9b27a65c17ff06fbf3 hmmer-3.4.tar.gz" | sha256sum --check \
    && tar zxf hmmer-3.4.tar.gz \
    && rm hmmer-3.4.tar.gz \
    && cp /app/alphafold/docker/jackhmmer_seq_limit.patch /hmmer_build/ \
    && patch -p0 < jackhmmer_seq_limit.patch \
    && cd /hmmer_build/hmmer-3.4 \
    && ./configure --prefix /hmmer \
    && make -j"$(nproc)" \
    && make install \
    && cd /hmmer_build/hmmer-3.4/easel \
    && make install \
    && rm -rf /hmmer_build

WORKDIR /app/alphafold

# Install AlphaFold3 dependencies using the repo lockfile.
ARG UV_EXTRAS=""

RUN --mount=type=cache,target=/root/.cache/uv \
    UV_LINK_MODE=hardlink uv sync --frozen --all-groups --no-editable ${UV_EXTRAS}

# Required by nf-core/proteinfold extract_metrics.py and CIF to PDB conversion
RUN uv pip install --python /alphafold3_venv/bin/python biopython

# Build chemical components database.
RUN uv run build_data

# Nextflow-friendly executable wrapper.
# This lets the module call simply:
#   run_alphafold ...
RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'exec uv run --project /app/alphafold python3 /app/alphafold/run_alphafold.py "$@"' \
    > /usr/local/bin/run_alphafold \
    && chmod +x /usr/local/bin/run_alphafold

# Optional compatibility alias.
RUN ln -s /usr/local/bin/run_alphafold /usr/local/bin/run_alphafold.py

# XLA / JAX settings.
# Required for NVIDIA GPUs with compute capability 7.x, e.g. V100/T4.
ENV XLA_FLAGS="--xla_disable_hlo_passes=custom-kernel-fusion-rewriter"
ENV XLA_PYTHON_CLIENT_PREALLOCATE=true
ENV XLA_CLIENT_MEM_FRACTION=0.95
