FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1 \
    TOKENIZERS_PARALLELISM=false \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    build-essential \
    ninja-build \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv "$VIRTUAL_ENV"

RUN pip install --upgrade pip setuptools wheel psutil

RUN python3 -m pip install \
    --index-url https://download.pytorch.org/whl/cu126 \
    torch torchvision torchaudio

RUN pip install cuequivariance cuequivariance-torch cuequivariance-ops-torch-cu12
RUN pip install --no-build-isolation flash-attn

ARG ESM_REF=main
RUN pip install "esm @ git+https://github.com/Biohub/esm.git@${ESM_REF}"

RUN pip check


#FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04 AS runtime
FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1 \
    TOKENIZERS_PARALLELISM=false \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    CC=/usr/bin/gcc \
    CXX=/usr/bin/g++

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-dev \
    ca-certificates \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 --shell /bin/bash appuser

COPY --from=builder /opt/venv /opt/venv

RUN mkdir -p /workspace && chown -R appuser:appuser /workspace

WORKDIR /workspace
USER appuser

CMD ["python"]
