FROM python:3.12-slim

LABEL org.opencontainers.image.title="nf-core/proteinfold_boltz" \
    org.opencontainers.image.description="Docker image containing all software requirements to run Boltz using the nf-core/proteinfold pipeline" \
    org.opencontainers.image.version="1.2.0dev" \
    org.opencontainers.image.authors="Jose Espinosa-Carrasco <espinosacarrascoj@gmail.com>Ziad Al-Bkhetan <ziad.albkhetan@gmail.com>" \
    org.opencontainers.image.source="https://github.com/nf-core/proteinfold" \
    org.opencontainers.image.licenses="MIT"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    procps \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir boltz==2.2.1

# The update to 2.2.1, was complaining about this missing dependencies
RUN pip install --no-cache-dir \
    cuequivariance_ops_cu12==0.8.1\
    cuequivariance_ops_torch_cu12==0.8.1 \
    cuequivariance_torch==0.8.1 \
    triton==3.3.0

CMD ["boltz"]
