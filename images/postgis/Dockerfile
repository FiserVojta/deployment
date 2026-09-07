# CloudNativePG operand image with PostGIS, built for arm64.
#
# Why this exists: the cluster runs on arm64 nodes, and upstream
# ghcr.io/cloudnative-pg/postgis publishes linux/amd64 only — every tag. The
# CNPG *postgresql* images are multi-arch, so we start from one of those and
# add PostGIS from PGDG, which does ship arm64 packages.
#
# Note: the "standard" variant does NOT contain barman-cloud — CNPG removed it
# from all operand images in favour of the Barman Cloud Plugin, which injects a
# sidecar instead. If backups are added later, that is the route; do not expect
# barman binaries here. "minimal" would also work for this image today.
#
# The base image already has the PGDG apt repository configured. Do not add it
# again — a second entry for the same source with a different signed-by keyring
# makes apt fail with "Conflicting values set for option Signed-By".
FROM ghcr.io/cloudnative-pg/postgresql:17.9-standard-bookworm

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql-17-postgis-3 \
        postgresql-17-postgis-3-scripts; \
    rm -rf /var/lib/apt/lists/*

# CNPG runs its operands as uid 26.
USER 26
