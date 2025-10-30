# CoolCorners ArgoCD Migration Guide

## Current Structure ✅
Your manifests are already well-organized and ready for ArgoCD!

```
inra/
├── backend/          # Backend API manifests
├── frontend/         # Frontend web app manifests
├── keycloak/         # Keycloak auth manifests
├── argocd/           # ArgoCD configurations
└── cluster-issuer.yaml
```

## Migration Steps

### 1. Push to Git Repository

```bash
cd /Users/vojtechfiser/Documents/private-projects/coolCorners/inra

# If not already a git repo
git init
git add .
git commit -m "Initial Kubernetes manifests for ArgoCD"

# Create a new repo on GitHub/GitLab, then:
git remote add origin https://github.com/YOURUSERNAME/coolcorners-k8s.git
git push -u origin main
```

### 2. Update ArgoCD Application Files

Edit these files and replace `YOURUSERNAME` with your actual GitHub username:
- `argocd/backend-app.yaml`
- `argocd/frontend-app.yaml`

### 3. Apply ArgoCD Applications

```bash
# Apply the backend app
kubectl apply -f argocd/backend-app.yaml

# Apply the frontend app
kubectl apply -f argocd/frontend-app.yaml
```

### 4. Verify in ArgoCD UI

Visit: https://argocd.coolcorners.org

You should see:
- coolcorners-backend
- coolcorners-frontend

### 5. Delete Old kubectl-Created Resources (Optional)

Once ArgoCD has synced and created the new resources, you can delete the old ones:

```bash
# Only do this after confirming ArgoCD apps are healthy!
kubectl delete deployment api -n app
kubectl delete deployment frontend -n app
```

ArgoCD will immediately recreate them from Git.

## Daily Workflow

After migration, your workflow becomes:

1. Edit YAML files locally or in GitHub
2. Commit and push to Git
3. ArgoCD automatically syncs (within 3 minutes)
4. No more `kubectl apply` needed!

## Tips

- **Automatic sync**: Enabled by default (changes deploy automatically)
- **Self-heal**: If you manually change something with kubectl, ArgoCD will revert it
- **Prune**: If you delete a file from Git, ArgoCD deletes it from cluster

## Need to Make Quick Changes?

You can still use kubectl for testing, but ArgoCD will revert your changes within 3 minutes. To make permanent changes, always update Git.
