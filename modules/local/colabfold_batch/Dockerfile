FROM ghcr.io/sokrypton/colabfold:1.5.5-cuda12.2.2

RUN mamba install -y -n colabfold -c conda-forge -c bioconda mmseqs2=18.8cc5c && \
    mamba clean -afy && \
    mmseqs version
