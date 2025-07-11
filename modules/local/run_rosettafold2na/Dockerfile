########################################################################
# Dockerfile for RoseTTAFold2NA (CUDA 12.2), auto-activating conda env
########################################################################
ARG CUDA=12.2.2
FROM nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu20.04 AS builder
# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA

LABEL Author="petrislp@gmail.com, Jose Espinosa-Carrasco" \
    Version="1.2.0dev" \
    description="Docker image containing all software requirements to run the RUN_ROSETTAFOLD2NA module using the nf-core/proteinfold pipeline"

# Switch default shell to bash for subsequent RUN commands
SHELL ["/bin/bash", "-c"]

# Add env variables
ENV PYTHONPATH="/app/RoseTTAFold2NA" \
    PATH="/conda/bin:/app/RoseTTAFold2NA:/conda/envs/RF2NA/bin:$PATH" \
    DGLBACKEND="pytorch" \
    LD_LIBRARY_PATH="/usr/local/cuda-$(cut -f1,2 -d. <<< ${CUDA})/lib64:$LD_LIBRARY_PATH" \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

########################################################################
# 1. Install minimal system dependencies and Miniforge (conda/mamba)
########################################################################
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    wget \
    git \
    curl \
    ncbi-blast+ \
    libopenblas0 \
    libopenblas-dev \
    locales \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && wget -q -P /tmp \
    "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" \
    && bash /tmp/Miniforge3-$(uname)-$(uname -m).sh -b -p /conda \
    && rm -rf /tmp/Miniforge3-$(uname)-$(uname -m).sh /var/lib/apt/lists/* \
    && apt-get autoremove -y && apt-get clean -y

########################################################################
# 2. Clone RoseTTAFold2NA repo, create conda environment, and pin DGL
########################################################################

## Using an add-hoc environment file to update dependencies
COPY environment_nfcore-proteinfold_rosettafold2na.yml ./environment.yml
RUN /conda/bin/mamba env create -f environment.yml 

RUN git clone --depth 1 https://github.com/uw-ipd/RoseTTAFold2NA.git /app/RoseTTAFold2NA && \
    cd /app/RoseTTAFold2NA && \
    /conda/bin/mamba run -n RF2NA bash -c "\
        cd SE3Transformer && \
        pip install --no-cache-dir -r requirements.txt && \
        python setup.py install" && \
    /conda/bin/mamba clean --all --force-pkgs-dirs -y

# ########################################################################
# # 3. Final clean-up: remove build tools and caches
# ########################################################################
RUN apt-get autoremove -y && \
    apt-get remove --purge -y wget git && \
    apt-get clean -y && \
    rm -rf /root/.cache

FROM nvidia/cuda:${CUDA}-base-ubuntu22.04
# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA

COPY --from=builder /app /app
COPY --from=builder /conda /conda

# Add env variables
ENV PYTHONPATH="/app/RoseTTAFold2NA" \
    PATH="/conda/bin:/app/RoseTTAFold2NA:/conda/envs/RF2NA/bin:$PATH" \
    DGLBACKEND="pytorch" \
    LD_LIBRARY_PATH="/usr/local/cuda-$(cut -f1,2 -d. <<< ${CUDA})/lib64:$LD_LIBRARY_PATH" \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
