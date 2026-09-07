# Migrating off Scaleway Managed Postgres

Moves `corners` (backend, PostGIS) and `keycloakdb` (Keycloak) from the managed
instance at `172.16.0.5` onto an in-cluster CloudNativePG cluster.

The manifests in this directory stand the new database up **empty and unused**.
Nothing repoints at it until step 5, so steps 1–4 are safe to do at any time.

## Step 0 — Prerequisites (do these first)

**Confirm the source version.** The target image is Postgres 17 / PostGIS 3.5.
A dump only restores forward, so the source must be 17 or older:

```bash
kubectl -n app run pgcheck --rm -it --restart=Never \
  --image=ghcr.io/cloudnative-pg/postgis:17-3.5-9 -- \
  psql "postgresql://doadmin@172.16.0.5:5432/corners" \
  -c "select version()" -c "select postgis_full_version()"
```

If the source is newer than 17, stop — `imageName` in `cluster.yaml` needs to
change and there is no PostGIS image for 18 yet.

**Check the data size** so 20Gi is sane (`storage.size` in `cluster.yaml`):

```bash
psql ... -c "select pg_size_pretty(pg_database_size('corners'))"
```

## Step 1 — Deploy the operator and the cluster

```bash
cd inra && git add -A && git commit -m "Add CloudNativePG cluster" && git push
```

ArgoCD creates `cnpg-operator` first, then `coolcorners-postgres`. Watch:

```bash
kubectl -n cnpg-system get pods
kubectl -n app get cluster,pvc
kubectl -n app get cluster postgres -o jsonpath='{.status.phase}'
```

Wait for phase `Cluster in healthy state`.

## Step 2 — Verify the empty cluster

```bash
kubectl -n app exec -it postgres-1 -- psql -c "\l"          # corners + keycloakdb
kubectl -n app exec -it postgres-1 -- psql -d corners -c "select postgis_version()"
```

If `keycloakdb` is missing, check the `Database` resource and that
`keycloak-db-creds` exists (see Troubleshooting).

## Step 3 — Stop writes

Auth and the API go down here. This is the maintenance window.

```bash
kubectl -n app scale deploy/api --replicas=0
kubectl -n keycloak scale statefulset/keycloak --replicas=0
```

## Step 4 — Dump and restore

Run a migration pod that can reach both databases:

```bash
kubectl -n app run pgmig --rm -it --restart=Never \
  --image=ghcr.io/cloudnative-pg/postgis:17-3.5-9 -- bash
```

Inside it (passwords from Infisical / the `postgres-app` secret):

```bash
# corners
PGPASSWORD='<managed doadmin pw>' pg_dump -Fc --no-owner --no-acl \
  -h 172.16.0.5 -U doadmin -d corners -f /tmp/corners.dump
PGPASSWORD='<postgres-app pw>' pg_restore --no-owner --no-acl \
  -h postgres-rw -U corners -d corners /tmp/corners.dump

# keycloakdb
PGPASSWORD='<managed keycloakadmin pw>' pg_dump -Fc --no-owner --no-acl \
  -h 172.16.0.5 -U keycloakadmin -d keycloakdb -f /tmp/kc.dump
PGPASSWORD='<KC_DB_PASSWORD>' pg_restore --no-owner --no-acl \
  -h postgres-rw -U keycloak -d keycloakdb /tmp/kc.dump
```

Restoring **as the target owner** is deliberate: with `--no-owner`, objects end
up owned by whoever runs the restore, and the app must own its own tables.

`extension "postgis" already exists` errors are expected and harmless — it comes
from template1 via `postInitTemplateSQL`.

Sanity-check row counts against the old instance before continuing. Flyway's
`flyway_schema_history` travels with the dump, so migrations will not re-run.

## Step 5 — Repoint the applications

Two files. `backend/deployment.yaml`:

```yaml
- name: SPRING_DATASOURCE_URL
  value: "jdbc:postgresql://postgres-rw.app.svc.cluster.local:5432/corners?currentSchema=app,public"
- name: SPRING_DATASOURCE_USERNAME
  valueFrom: { secretKeyRef: { name: postgres-app, key: username } }
- name: DB_PASSWORD
  valueFrom: { secretKeyRef: { name: postgres-app, key: password } }
```

`sslmode=require` is dropped: traffic stays inside the cluster and the CNPG
server does not present a certificate the client would trust.

`argocd/keycloak-app.yaml`, in the Helm values:

```yaml
- name: KC_DB_URL_HOST
  value: "postgres-rw.app.svc.cluster.local"
- name: KC_DB_USERNAME
  value: "keycloak"          # was keycloakadmin
# KC_DB_URL_PROPERTIES: delete this entry entirely (was "?sslmode=require")
```

`KC_DB_PASSWORD` is unchanged — CNPG sets the same Infisical value on the role.

Commit, push, and scale back up:

```bash
kubectl -n app scale deploy/api --replicas=1
kubectl -n keycloak scale statefulset/keycloak --replicas=1
```

## Step 6 — Verify

```bash
kubectl -n app logs deploy/api | grep -i flyway     # "Successfully validated", no migrations run
curl -sS https://coolcorners.org/api/actuator/health
kubectl -n keycloak logs statefulset/keycloak | tail -30
```

Then log in through the UI — that exercises Keycloak's database end to end.

## Step 7 — Decommission

**Read this before deleting anything.** There are no backups configured, so
once the managed instance is gone the only copy of your data is the single
Scaleway volume behind `postgres-1`. There is no point-in-time recovery and
nothing to restore from if that volume is lost or the data is corrupted.

At minimum, before decommissioning:

```bash
# Take a dump and store it OFF the cluster — not in the same bucket the app
# uploads to, and not only on the volume you are protecting against.
kubectl -n app exec postgres-1 -- pg_dump -Fc -d corners    > corners-$(date +%F).dump
kubectl -n app exec postgres-1 -- pg_dump -Fc -d keycloakdb > keycloakdb-$(date +%F).dump
```

Consider keeping the managed instance running until real backups exist. It is
the cheapest safety net you will ever have for this data.

## Rollback

Until step 7, rollback is reverting the step 5 commit — the managed instance is
still there, untouched and still holding the data.

## Troubleshooting

**`keycloak-db-creds` is empty or missing** — the Infisical template syntax in
`keycloak-db-creds.yaml` (`{{ .KC_DB_PASSWORD.Value }}`) is the one thing here
that could not be verified ahead of time. If it does not render, replace that
InfisicalSecret with a plain basic-auth Secret holding `username: keycloak` and
the same password, and the rest is unaffected.

**Cluster stuck in `Setting up primary`** — usually the PVC. Check
`kubectl -n app describe pvc postgres-1` and that `sbs-default-retain` exists.

## What this setup does not give you

- **No backups at all.** Deliberately deferred. Nothing is archived anywhere;
  the retained volume is the only copy. Losing it loses the data.
- **No point-in-time recovery.** There is no way to rewind to before a bad
  migration, a bad delete, or corruption.
- **No HA.** One instance on a one-node cluster. Node dies, database is down
  until it comes back; the volume is retained, so data survives that case.

Adding backups later is the Barman Cloud Plugin (chart `plugin-barman-cloud`),
which injects a barman-cloud sidecar; the S3 settings map over unchanged.
