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

RUN pip install --no-cache-dir boltz==2.0.3

## To update to version 2.2.0, uncomment the following lines, though still was complaining
## about triton version, thought the error msg state to be sure of using 3.3.0
# RUN pip install --no-cache-dir \
#     cuequivariance_ops_cu12==0.5.1\
#     cuequivariance_ops_torch_cu12==0.5.1 \
#     cuequivariance_torch==0.5.1 \
#     triton==3.3.0

CMD ["boltz"]
