ARG CUDA_VERSION=12.2.2
FROM nvidia/cuda:${CUDA_VERSION}-cudnn8-runtime-ubuntu22.04
# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA_VERSION

LABEL org.opencontainers.image.title="nf-core/proteinfold_alphafold2_pred" \
    org.opencontainers.image.description="Docker image containing all software requirements to run the RUN_ALPHAFOLD2_PRED module using the nf-core/proteinfold pipeline" \
    org.opencontainers.image.version="2.1.0" \
    org.opencontainers.image.authors="Athanasios Baltzis, Jose Espinosa-Carrasco <espinosacarrascoj@gmail.com>, Leila Mansouri" \
    org.opencontainers.image.source="https://github.com/nf-core/proteinfold" \
    org.opencontainers.image.licenses="MIT"

# Use bash to support string substitution.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ADD --checksum=sha256:65af53dad30b3fcbd1cb1d4ad62fd3a86221464754844544558aae3a28795189 https://github.com/conda-forge/miniforge/releases/download/24.11.3-2/Miniforge3-24.11.3-2-Linux-x86_64.sh /tmp/miniforge.sh
RUN bash /tmp/miniforge.sh -b -p /opt/conda && rm /tmp/miniforge.sh

ENV PATH="/opt/conda/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/conda/lib:$LD_LIBRARY_PATH"
ENV CONDA_PLUGINS_AUTO_ACCEPT_TOS="yes"
RUN conda install --quiet --yes conda==24.11.1 pip python=3.11 git \
    && conda clean --all --force-pkgs-dirs --yes

ARG ALPHAFOLD_COMMIT=c77e5d2a8961d1a353632c462914ff0a32a950f6
RUN git clone https://github.com/google-deepmind/alphafold.git /app/alphafold && \
    git -C /app/alphafold checkout --detach ${ALPHAFOLD_COMMIT}

COPY run_predict.py /app/alphafold/run_predict.py

RUN mamba install --quiet --yes cuda-toolkit=${CUDA_VERSION} \
    && mamba clean --all --force-pkgs-dirs --yes

ADD --checksum=sha256:24510899eeb49167cffedec8fa45363a4d08279c0c637a403b452f7d0ac09451 https://raw.githubusercontent.com/metalcycling/openstructure/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt /app/alphafold/alphafold/common/stereo_chemical_props.txt

# Install pip packages.
RUN pip3 install --upgrade pip --no-cache-dir \
    && pip3 install -r /app/alphafold/requirements.txt --no-cache-dir \
    && pip3 install --no-cache-dir \
      jax==0.4.26 \
      jaxlib==0.4.26+cuda12.cudnn89 \
      -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html \
    && pip3 install --no-cache-dir --no-deps OpenMM-CUDA-12==8.2.0

# Add SETUID bit to the ldconfig binary so that non-root users can run it.
RUN chmod u+s /sbin/ldconfig.real

# Currently needed to avoid undefined_symbol error.
RUN ln -sf /usr/lib/x86_64-linux-gnu/libffi.so.7 /opt/conda/lib/libffi.so.7

# Run ldconfig to ensure GPUs are visible at runtime.
# See https://github.com/NVIDIA/nvidia-docker/issues/1399
RUN ldconfig

WORKDIR /app/alphafold
