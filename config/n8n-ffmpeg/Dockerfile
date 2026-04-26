ARG N8N_VERSION=latest
FROM mwader/static-ffmpeg:7.1.1 AS ffmpeg

FROM n8nio/n8n:${N8N_VERSION}

USER root

COPY --from=ffmpeg /ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg /ffprobe /usr/local/bin/ffprobe

RUN chmod 0755 /usr/local/bin/ffmpeg /usr/local/bin/ffprobe \
    && /usr/local/bin/ffmpeg -hide_banner -version \
    && /usr/local/bin/ffprobe -hide_banner -version

USER node
