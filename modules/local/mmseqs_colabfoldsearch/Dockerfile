ARG COLABFOLD_REF=c35de0221f4d297a39edf4cf292ba2832e321edc
ARG MMSEQS2_REPOSITORY=https://github.com/jscgh/MMseqs2.git
ARG MMSEQS2_REF=de9e40daacf4cf73bde87ab6eb9c3de392f1281b

FROM --platform=linux/amd64 ghcr.io/steineggerlab/build-containers:main-x86_64 AS mmseqs-builder

ARG MMSEQS2_REPOSITORY
ARG MMSEQS2_REF

WORKDIR /opt/mmseqs2

RUN git init . && \
    git remote add origin "${MMSEQS2_REPOSITORY}" && \
    git fetch --depth 1 origin "${MMSEQS2_REF}" && \
    git checkout --detach FETCH_HEAD && \
    cmake -S . -B build -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DHAVE_TESTS=0 \
        -DHAVE_SSE4_1=1 \
        -DFORCE_STATIC_DEPS=1 && \
    cmake --build build -j"$(nproc)"

FROM ubuntu:24.04

ARG COLABFOLD_REF

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
        git \
        build-essential \
        cmake && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    \
    pip install --no-cache-dir --break-system-packages \
        "colabfold @ git+https://github.com/sokrypton/ColabFold.git@${COLABFOLD_REF}" && \
    \
    apt-get remove -y \
        python3-dev \
        git \
        build-essential \
        cmake && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    pip cache purge

COPY --from=mmseqs-builder /opt/mmseqs2/build/src/mmseqs /usr/local/bin/mmseqs

RUN mmseqs version

ENV MPLBACKEND=Agg
ENV MPLCONFIGDIR=/tmp/mplconfig
ENV XDG_CACHE_HOME=/tmp/xdg_cache
