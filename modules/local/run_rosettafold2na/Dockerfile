########################################################################
# Dockerfile for RoseTTAFold2NA (CUDA 11.7), auto-activating conda env
########################################################################
FROM nvidia/cuda:11.7.1-cudnn8-devel-ubuntu22.04

LABEL Author="petrislp@gmail.com" \
    title="nfcore/proteinfold_rosettafold2na" \
    description="Docker image containing all software requirements to run RoseTTAFold2NA" \
    version="1.2.0dev"

# Switch default shell to bash for subsequent RUN commands
SHELL ["/bin/bash", "-c"]

# Environment variables
ENV PYTHONPATH="/app/RoseTTAFold2NA" \
    PATH="/conda/bin:/app/RoseTTAFold2NA:/conda/envs/RF2NA/bin:$PATH" \
    DGLBACKEND="pytorch" \
    LD_LIBRARY_PATH="/conda/lib:/usr/local/cuda-11.7/lib64:$LD_LIBRARY_PATH" \
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
RUN git clone --depth 1 https://github.com/uw-ipd/RoseTTAFold2NA.git /app/RoseTTAFold2NA && \
    cd /app/RoseTTAFold2NA && \
    # Remove the default channel to avoid conflicts with conda-forge
    sed -i '/- defaults/d' RF2na-linux.yml && \
    /conda/bin/mamba env create -f RF2na-linux.yml && \
    /conda/bin/mamba run -n RF2NA bash -c "\
        conda install -y -c dglteam/label/cu117 dgl=1.1.2 && \
        conda clean --all --force-pkgs-dirs -y" && \
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

# # Use a login shell so ~/.bashrc is executed (activating RF2NA by default)
CMD ["/bin/bash", "--login"]
