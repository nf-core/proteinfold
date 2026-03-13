FROM ubuntu:24.04
ARG MMSEQS2_VERSION=18-8cc5c

LABEL org.opencontainers.image.title="nf-core/proteinfold_mmseqs_colabfoldsearch" \
    org.opencontainers.image.description="Lightweight Docker image containing all software requirements to run the MMSEQS_COLABFOLDSEARCH module using the nf-core/proteinfold pipeline" \
    org.opencontainers.image.version="2.0.0" \
    org.opencontainers.image.authors="Joshua Storm Caley <j.caley@unsw.edu.au>" \
    org.opencontainers.image.source="https://github.com/nf-core/proteinfold" \
    org.opencontainers.image.licenses="MIT"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-dev \
        python3-pip \
        wget \
        git \
        build-essential \
        cmake && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    \
    pip install --no-cache-dir --break-system-packages \
        "colabfold @ git+https://github.com/sokrypton/ColabFold.git@e8ebd9a" && \
    \
    wget -q https://github.com/soedinglab/MMseqs2/releases/download/${MMSEQS2_VERSION}/mmseqs-linux-sse41.tar.gz && \
    tar xzf mmseqs-linux-sse41.tar.gz && \
    cp mmseqs/bin/* /usr/local/bin/ && \
    rm -rf mmseqs mmseqs-linux-sse41.tar.gz && \
    \
    apt-get remove -y \
        python3-dev \
        wget \
        git \
        build-essential \
        cmake && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    pip cache purge

ENV MPLBACKEND=Agg
ENV MPLCONFIGDIR=/tmp/mplconfig
ENV XDG_CACHE_HOME=/tmp/xdg_cache
