FROM debian:bullseye

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    texlive-full poppler-utils \
    osm2pgsql postgresql-client \
    python3-pygments python3-geopandas \
    latexmk make \
    docker.io
