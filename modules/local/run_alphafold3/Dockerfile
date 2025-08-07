FROM nvidia/cuda:12.6.0-base-ubuntu22.04

LABEL authors="Jose Espinosa-Carrasco" \
    title="nfcore/proteinfold_alphafold3" \
    Version="1.2.0dev" \
    description="Docker image containing all software requirements to run Alphafold3 using the nf-core/proteinfold pipeline"

# Some RUN statements are combined together to make Docker build run faster.
# Get latest package listing, install software-properties-common, git and wget.
# git is required for pyproject.toml toolchain's use of CMakeLists.txt.
RUN apt update --quiet \
    && apt install --yes --quiet software-properties-common \
    && apt install --yes --quiet git wget jq \
    && rm -rf /var/lib/apt/lists/*

# Get apt repository of specific Python versions. Then install Python. Tell APT
# this isn't an interactive TTY to avoid timezone prompt when installing.
RUN add-apt-repository ppa:deadsnakes/ppa \
    && DEBIAN_FRONTEND=noninteractive apt install --yes --quiet python3.11 python3-pip python3.11-venv python3.11-dev
RUN python3.11 -m venv /alphafold3_venv
ENV PATH="/hmmer/bin:/alphafold3_venv/bin:$PATH"

# Install HMMER. Do so before copying the source code, so that docker can cache
# the image layer containing HMMER.
RUN mkdir /hmmer_build /hmmer ; \
    wget http://eddylab.org/software/hmmer/hmmer-3.4.tar.gz --directory-prefix /hmmer_build ; \
    (cd /hmmer_build && tar zxf hmmer-3.4.tar.gz && rm hmmer-3.4.tar.gz) ; \
    (cd /hmmer_build/hmmer-3.4 && ./configure --prefix /hmmer) ; \
    (cd /hmmer_build/hmmer-3.4 && make -j8) ; \
    (cd /hmmer_build/hmmer-3.4 && make install) ; \
    (cd /hmmer_build/hmmer-3.4/easel && make install) ; \
    rm -R /hmmer_build

# Clone AlphaFold3
RUN git clone https://github.com/google-deepmind/alphafold3.git /app/alphafold && \
    cd /app/alphafold && \
    git checkout 3c27a149a25b6c8930ce68cfeb2a6cbb9afb3359 && \
    cd -

# # Install the Python dependencies AlphaFold 3 needs.
# RUN pip3 install -r dev-requirements.txt
# RUN pip3 install --no-deps .

# Install pip packages.
RUN pip3 install --upgrade pip --no-cache-dir \
    && pip3 install -r /app/alphafold/dev-requirements.txt --no-cache-dir \
    && pip3 install --no-deps /app/alphafold/ --no-cache-dir \
    && pip3 install --no-deps biopython

# # Build chemical components database (this binary was installed by pip).
RUN build_data

# To work around a known XLA issue causing the compilation time to greatly
# increase, the following environment variable setting XLA flags must be enabled
# when running AlphaFold 3:
ENV XLA_FLAGS="--xla_gpu_enable_triton_gemm=false"
# Memory settings used for folding up to 5,120 tokens on A100 80 GB.
ENV XLA_PYTHON_CLIENT_PREALLOCATE=true
ENV XLA_CLIENT_MEM_FRACTION=0.95
