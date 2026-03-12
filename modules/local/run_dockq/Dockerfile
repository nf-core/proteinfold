FROM community.wave.seqera.io/library/dockq:2.1.3--12e64dc3fc7d0a10

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

CMD ["DockQ"]