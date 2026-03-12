FROM pytorch/pytorch:2.7.1-cuda12.6-cudnn9-devel

LABEL authors="nf-core proteinfold" \
      description="Docker image for Protenix in nf-core/proteinfold" \
      maintainer="nf-core"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    CUTLASS_PATH=/opt/cutlass \
    PROTENIX_ROOT_DIR=/data/protenix_cache

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        g++ \
        gcc \
        libc6-dev \
        make \
        hmmer \
        kalign \
        procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone CUTLASS for deepspeed kernels
RUN git clone -b v3.5.1 https://github.com/NVIDIA/cutlass.git /opt/cutlass

# Install Protenix from PyPI
RUN pip install --no-cache-dir protenix==1.0.6

# Install additional dependencies for nf-core integration
RUN pip install --no-cache-dir biopython gemmi

# Create cache directory
RUN mkdir -p /data/protenix_cache

# Copy helper scripts into container
COPY fasta_to_protenix_json.py /usr/local/bin/fasta_to_protenix_json.py
COPY protenix_extract_metrics.py /usr/local/bin/protenix_extract_metrics.py
RUN chmod +x /usr/local/bin/fasta_to_protenix_json.py /usr/local/bin/protenix_extract_metrics.py

WORKDIR /work
