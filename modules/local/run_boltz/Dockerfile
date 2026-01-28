FROM python:3.12-slim

LABEL authors="Ziad Al-Bkhetan <ziad.albkhetan@gmail.com>" \
    title="nfcore/proteinfold_boltz" \
    Version="1.2.0dev" \
    description="Docker image containing all software requirements to run boltz using the nf-core/proteinfold pipeline"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    procps \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir boltz==2.2.1

# The update to 2.2.1, was complaining about this missing dependencies
RUN pip install --no-cache-dir \
    cuequivariance_ops_cu12==0.5.1\
    cuequivariance_ops_torch_cu12==0.5.1 \
    cuequivariance_torch==0.5.1 \
    triton==3.3.0

CMD ["boltz"]
