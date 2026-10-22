FROM python:3.11-slim-bookworm

LABEL org.opencontainers.image.title="nf-core/proteinfold_alphafold2_msa" \
    org.opencontainers.image.description="AlphaFold2 CPU MSA and template feature generation for nf-core/proteinfold" \
    org.opencontainers.image.version="2.1.0" \
    org.opencontainers.image.source="https://github.com/nf-core/proteinfold" \
    org.opencontainers.image.licenses="MIT"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    git \
    procps \
    hhsuite \
    hmmer \
    kalign \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG ALPHAFOLD_COMMIT=c77e5d2a8961d1a353632c462914ff0a32a950f6
RUN git clone https://github.com/google-deepmind/alphafold.git /app/alphafold && \
    git -C /app/alphafold checkout --detach ${ALPHAFOLD_COMMIT}

COPY run_msa.py /app/alphafold/run_msa.py

ADD --checksum=sha256:24510899eeb49167cffedec8fa45363a4d08279c0c637a403b452f7d0ac09451 https://raw.githubusercontent.com/metalcycling/openstructure/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt /app/alphafold/alphafold/common/stereo_chemical_props.txt

RUN pip install --no-cache-dir \
    absl-py==1.0.0 \
    biopython==1.79 \
    jax==0.4.26 \
    jaxlib==0.4.26 \
    numpy==1.24.3 \
    scipy==1.11.4

WORKDIR /app/alphafold
