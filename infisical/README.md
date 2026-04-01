# Infisical Setup For `inra`

This keeps your current app deployments unchanged and replaces plaintext Kubernetes `Secret` manifests with `InfisicalSecret` resources that create the same target secret names.

Current secret consumers in this repo:
- `backend/deployment.yaml` expects Kubernetes secret `db-creds` in namespace `app`
- `tato-backend/deployment.yaml` expects Kubernetes secret `tato-app-secrets` in namespace `tato`
- `keycloak/keycloak-values.yaml` still contains plaintext credentials and should be migrated separately

## Recommended Shape

Use:
- Infisical Cloud or self-hosted Infisical
- one Infisical project, for example `coolcorners`
- environment `prod`
- paths:
  - `/backend`
  - `/tato-backend`
  - `/keycloak`
- Infisical Kubernetes Operator installed cluster-wide
- Universal Auth for the first rollout because it is simpler to bootstrap than Kubernetes Auth

This is the easiest migration path for your current Argo CD style manifests.

## Secrets To Create In Infisical

Path `/backend`:
- `username`
- `password`

Path `/tato-backend`:
- `db-username`
- `db-password`
- `keycloak-admin-client-secret`

Path `/keycloak`:
- `admin-password`
- `db-password`

## 1. Install The Operator

Official docs:
- `https://infisical.com/docs/integrations/platforms/kubernetes`
- `https://infisical.com/docs/integrations/platforms/kubernetes/infisical-secret-crd`

Install with Helm:

```bash
helm repo add infisical-helm-charts 'https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/'
helm repo update
helm upgrade --install infisical-operator infisical-helm-charts/secrets-operator \
  --namespace infisical-system \
  --create-namespace
```

## 2. Create A Machine Identity In Infisical

In Infisical:
1. Create or open your project.
2. Create environment `prod`.
3. Create a Machine Identity with read access to the paths listed above.
4. Generate Universal Auth credentials for that identity.

You will get:
- `clientId`
- `clientSecret`
- your project slug

## 3. Bootstrap The Universal Auth Credentials Into Kubernetes

Do not commit real credentials into Git.

Use the example file in this folder and apply it manually after replacing placeholders:

```bash
kubectl apply -f inra/infisical/universal-auth-credentials.example.yaml
```

This creates a bootstrap Kubernetes secret in namespace `infisical-system`. The example `InfisicalSecret` resources in this folder reference that bootstrap secret from there.

## 4. Apply The InfisicalSecret Resources

Fill in:
- `REPLACE_WITH_PROJECT_SLUG`
- `REPLACE_WITH_ENV_SLUG`

Then apply:

```bash
kubectl apply -f inra/infisical/backend-infisical-secret.yaml
kubectl apply -f inra/infisical/tato-backend-infisical-secret.yaml
```

These resources create and keep updated:
- secret `db-creds` in namespace `app`
- secret `tato-app-secrets` in namespace `tato`

Your existing deployments can keep using `secretKeyRef` exactly as they do now.

## 5. Validate

```bash
kubectl get infisicalsecrets.secrets.infisical.com -A
kubectl get secret db-creds -n app
kubectl get secret tato-app-secrets -n tato
kubectl describe infisicalsecret backend-secrets -n app
kubectl describe infisicalsecret tato-backend-secrets -n tato
```

Then restart workloads if needed:

```bash
kubectl rollout restart deployment/api -n app
kubectl rollout restart deployment/tato-api -n tato
```

## 6. After Validation

After the Infisical-managed secrets are working:
- remove plaintext files `inra/backend/secret-db.yaml` and `inra/tato-backend/secret-app.yaml`
- remove plaintext credentials from `inra/keycloak/keycloak-values.yaml`
- clean the `notes` file because it currently contains plaintext credentials and tokens

Do not do that cleanup until the operator-backed secrets are confirmed in cluster.

## Keycloak Migration Note

`keycloak/keycloak-values.yaml` currently embeds secrets directly in Helm values. That needs a second step because the chart must be changed to read from an existing Kubernetes secret instead of inline values.

Recommended target:
- Infisical syncs a Kubernetes secret like `keycloak-secrets` into namespace `keycloak`
- the Keycloak chart values are updated to read admin and DB credentials from that secret

I did not change the Keycloak values yet because that needs the exact chart value keys for the chart version you are using.
