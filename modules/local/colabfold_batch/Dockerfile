ARG CUDA_VERSION=12.9.1
FROM nvidia/cuda:${CUDA_VERSION}-base-ubuntu24.04
ARG CUDA_VERSION=12.9.1

LABEL Author="Joshua Storm Caley" \
    title="nf-core/proteinfold_colabfold" \
    Version="2.0.0dev" \
    description="Docker image containing all software requirements to run the COLABFOLD_BATCH module using the nf-core/proteinfold pipeline"

RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        wget \
        git \
        cuda-nvcc-$(echo $CUDA_VERSION | cut -d'.' -f1,2 | tr '.' '-') && \
    \
    wget -qnc https://github.com/conda-forge/miniforge/releases/download/24.11.0-0/Miniforge3-24.11.0-0-Linux-x86_64.sh && \
    bash Miniforge3-24.11.0-0-Linux-x86_64.sh -bfp /usr/local && \
    rm -f Miniforge3-24.11.0-0-Linux-x86_64.sh && \
    \
    CONDA_OVERRIDE_CUDA=$(echo $CUDA_VERSION | cut -d'.' -f1,2) mamba install -c conda-forge -c nvidia -c bioconda \
        openmm pdbfixer kalign2=2.04 hhsuite=3.3.0 -y && \
    \
    pip install --no-cache-dir --no-warn-conflicts "colabfold[alphafold-minus-jax] @ git+https://github.com/sokrypton/ColabFold.git@e8ebd9a" && \
    pip install --no-cache-dir silence_tensorflow && \
    pip uninstall -y jax jaxlib || true && \
    pip install --no-cache-dir "jax[cuda12]==0.5.3" "jaxlib==0.5.3" && \
    \
    mamba clean -a -y && \
    rm -rf /usr/local/pkgs && \
    find /usr/local -name "*.pyc" -delete && \
    find /usr/local -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true && \
    rm -rf /usr/local/share/doc /usr/local/share/man /usr/local/share/info && \
    \
    apt-get remove -y wget git && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    pip cache purge

ENV MPLBACKEND=Agg
ENV MPLCONFIGDIR=/tmp/mplconfig
ENV XDG_CACHE_HOME=/tmp/xdg_cache
ENV XLA_FLAGS="--xla_gpu_cuda_data_dir=/usr/local/cuda"
ENV CUDA_ROOT="/usr/local/cuda"
