ARG CUDA_VERSION=12.2.2
FROM nvidia/cuda:${CUDA_VERSION}-cudnn8-runtime-ubuntu20.04
# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA_VERSION

LABEL org.opencontainers.image.title="nf-core/proteinfold_alphafold2_pred" \
    org.opencontainers.image.description="Docker image containing all software requirements to run the RUN_ALPHAFOLD2_PRED module using the nf-core/proteinfold pipeline" \
    org.opencontainers.image.version="2.0.0" \
    org.opencontainers.image.authors="Athanasios Baltzis, Jose Espinosa-Carrasco <espinosacarrascoj@gmail.com>, Leila Mansouri" \
    org.opencontainers.image.source="https://github.com/nf-core/proteinfold" \
    org.opencontainers.image.licenses="MIT"

# Use bash to support string substitution.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A4B469963BF863CC
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    build-essential \
    cmake \
    cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA_VERSION//./-}) \
    git \
    hmmer \
    kalign \
    tzdata \
    wget \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y \
    && apt-get clean

# Clone AlphaFold2
RUN git clone https://github.com/cbcrg/alphafold.git /app/alphafold && \
    cd /app/alphafold && \
    git checkout 1b3170e9409472ec8ad044f9935c92bedd7b4674 && \
    cd -

# Compile HHsuite from source
RUN git clone --branch v3.3.0 --single-branch https://github.com/soedinglab/hh-suite.git /tmp/hh-suite \
    && mkdir /tmp/hh-suite/build \
    && pushd /tmp/hh-suite/build \
    && cmake -DCMAKE_INSTALL_PREFIX=/opt/hhsuite .. \
    && make -j && make install \
    && ln -s /opt/hhsuite/bin/* /usr/bin \
    && popd \
    && rm -rf /tmp/hh-suite

# Install Miniforge package manager
RUN wget -q -P /tmp \
    "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" \
    && bash /tmp/Miniforge3-$(uname)-$(uname -m).sh -b -p /opt/conda \
    && rm /tmp/Miniforge3-$(uname)-$(uname -m).sh

# Install Conda packages.
ENV PATH="/opt/conda/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/conda/lib:$LD_LIBRARY_PATH"
ENV CONDA_PLUGINS_AUTO_ACCEPT_TOS="yes"
RUN conda install --quiet --yes conda==24.11.1 pip python=3.11 \
    && conda install --quiet --yes --channel nvidia cuda=${CUDA_VERSION} \
    && conda install --quiet --yes --channel conda-forge openmm=8.0.0 pdbfixer \
    && conda clean --all --force-pkgs-dirs --yes

RUN mamba install --quiet --yes cuda-toolkit=${CUDA_VERSION} \
    && mamba clean --all --force-pkgs-dirs --yes

RUN wget -q -P /app/alphafold/alphafold/common/ \
    https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

# Download updated requirements.txt
RUN wget -q -O /app/alphafold/updated_requirements.txt https://raw.githubusercontent.com/google-deepmind/alphafold/e1554305c03c0f002a13e8d5bccc2239927f63d6/requirements.txt
RUN echo -e "chex==0.0.7\ndm-tree==0.1.8\nimmutabledict==2.0.0\npandas==2.0.3" >> /app/alphafold/updated_requirements.txt

# Install pip packages.
RUN pip3 install --upgrade pip --no-cache-dir \
    && pip3 install -r /app/alphafold/updated_requirements.txt --no-cache-dir \
    && pip3 install --upgrade --no-cache-dir \
      jax==0.4.26 \
      jaxlib==0.4.26+cuda12.cudnn89 \
      -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

RUN sed -i "s|alphafold/common/stereo_chemical_props.txt|/app/alphafold/alphafold/common/stereo_chemical_props.txt|g" /app/alphafold/alphafold/common/residue_constants.py

# Add SETUID bit to the ldconfig binary so that non-root users can run it.
RUN chmod u+s /sbin/ldconfig.real

# Currently needed to avoid undefined_symbol error.
RUN ln -sf /usr/lib/x86_64-linux-gnu/libffi.so.7 /opt/conda/lib/libffi.so.7

# Run ldconfig to ensure GPUs are visible at runtime.
# See https://github.com/NVIDIA/nvidia-docker/issues/1399
RUN ldconfig

WORKDIR /app/alphafold
