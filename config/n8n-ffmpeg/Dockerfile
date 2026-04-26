ARG N8N_VERSION=latest
FROM n8nio/n8n:${N8N_VERSION}

USER root

RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache ffmpeg; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends ffmpeg; \
      rm -rf /var/lib/apt/lists/*; \
    else \
      echo "Unsupported n8n base image: no apk or apt-get found" >&2; \
      exit 1; \
    fi; \
    command -v ffmpeg; \
    ffmpeg -hide_banner -version

USER node
