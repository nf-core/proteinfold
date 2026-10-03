ARG CUDA_VERSION=12.9.1
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu24.04

ARG COLABFOLD_COMMIT=f850f0f22f007355bd264d48e9ed263d59331426

LABEL org.opencontainers.image.title="nf-core/proteinfold_colabfold2" \
      org.opencontainers.image.description="ColabFold AF3 preview runtime for ProteinFold" \
      org.opencontainers.image.version="af3-preview-f850f0f" \
      org.opencontainers.image.source="https://github.com/sokrypton/ColabFold/tree/f850f0f22f007355bd264d48e9ed263d59331426" \
      org.opencontainers.image.revision="f850f0f22f007355bd264d48e9ed263d59331426" \
      org.opencontainers.image.licenses="MIT; model weights have separate terms"

COPY requirements.lock /opt/colabfold-requirements.lock

# requirements.lock was captured from the published af3-preview-f850f0f image; keep the pins fixed
# so rebuilding this source cannot silently pick a different JAX runtime or transitive dependency.
RUN apt-get update && \
    apt-get install -y --no-install-recommends git python3 python3-pip python3-venv && \
    python3 -m venv /opt/colabfold && \
    /opt/colabfold/bin/pip install --no-cache-dir "pip==26.2.1" && \
    /opt/colabfold/bin/pip install --no-cache-dir -r /opt/colabfold-requirements.lock && \
    apt-get purge -y git && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /root/.cache

# Prebuild alphafold3's chemical component tables, which otherwise get written into site-packages
# on first use and fail under read-only runtimes; components.cif is staged via params/af3/libcifpp/.
RUN mkdir /tmp/ccd_build && \
    /opt/colabfold/bin/python -c "from colabfold.alphafold3 import require; require('/tmp/ccd_build'); require('/tmp/ccd_build')" && \
    rm -rf /tmp/ccd_build

ENV PATH="/opt/colabfold/bin:${PATH}" \
    MPLBACKEND=Agg \
    MPLCONFIGDIR=/tmp/mplconfig \
    XDG_CACHE_HOME=/tmp/xdg_cache \
    JAX_COMPILATION_CACHE_DIR=/tmp/jax_cache
