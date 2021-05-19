FROM debian:bullseye

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    texlive-full poppler-utils \
    osm2pgsql postgresql-client \
    python3-pygments python3-geopandas \
    latexmk make \
    docker.io

COPY layer2img.py /tmp/layer2img.py
RUN python3 /tmp/layer2img.py -o /tmp/foo.pdf && \
        rm /tmp/layer2img.py /tmp/foo.pdf
