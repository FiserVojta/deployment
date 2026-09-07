# CloudNativePG operand image with PostGIS, built for arm64.
#
# Why this exists: the cluster runs on arm64 nodes, and upstream
# ghcr.io/cloudnative-pg/postgis publishes linux/amd64 only — every tag. The
# CNPG *postgresql* images are multi-arch, so we start from one of those and
# add PostGIS from PGDG, which does ship arm64 packages.
#
# The "standard" variant is required, not the "minimal" one: it carries the
# barman-cloud tooling that spec.backup.barmanObjectStore depends on.
FROM ghcr.io/cloudnative-pg/postgresql:17.9-standard-bookworm

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    install -d /usr/share/postgresql-common/pgdg; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc; \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql-17-postgis-3 \
        postgresql-17-postgis-3-scripts; \
    apt-get purge -y --auto-remove curl gnupg; \
    rm -rf /var/lib/apt/lists/*

# CNPG runs its operands as uid 26.
USER 26
