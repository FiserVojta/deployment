#!/bin/bash

# CoolCorners.org Deployment Script
# This script applies all Kubernetes configurations for coolcorners.org domain

set -e  # Exit on any error

echo "=========================================="
echo "CoolCorners.org Kubernetes Deployment"
echo "=========================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"
echo ""

# Define the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "📂 Working directory: $SCRIPT_DIR"
echo ""

# Step 1: Apply Cluster Issuer
echo "Step 1/5: Applying Cluster Issuer (Let's Encrypt)..."
kubectl apply -f "$SCRIPT_DIR/cluster-issuer.yaml"
echo "✅ Cluster Issuer applied"
echo ""

# Wait a bit for the issuer to be ready
sleep 2

# Step 2: Apply Backend Ingress
echo "Step 2/5: Applying Backend Ingress (https://coolcorners.org/api)..."
kubectl apply -f "$SCRIPT_DIR/backend/ingress-ip-prefix.yaml"
echo "✅ Backend Ingress applied"
echo ""

# Step 3: Apply Frontend Ingress
echo "Step 3/5: Applying Frontend Ingress (https://coolcorners.org/)..."
kubectl apply -f "$SCRIPT_DIR/frontend/ingress-ip-prefix.yaml"
echo "✅ Frontend Ingress applied"
echo ""

# Step 4: Apply Keycloak Ingress
echo "Step 4/5: Applying Keycloak Ingress (https://coolcorners.org/keycloak)..."
kubectl apply -f "$SCRIPT_DIR/keycloak/keycloak-ingress-ip-prefix.yaml"
echo "✅ Keycloak Ingress applied"
echo ""

# Step 5: Apply ArgoCD Ingress
echo "Step 5/5: Applying ArgoCD Ingress (https://coolcorners.org/argocd)..."
kubectl apply -f "$SCRIPT_DIR/argocd/argocd-ingress.yaml"
echo "✅ ArgoCD Ingress applied"
echo ""

echo "=========================================="
echo "✅ All configurations applied successfully!"
echo "=========================================="
echo ""

# Display status
echo "📊 Checking ingress status..."
kubectl get ingress -A
echo ""

echo "📊 Checking certificate status (may take a few minutes to issue)..."
kubectl get certificate -A
echo ""

echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Verify DNS records are pointing to your cluster IP:"
echo "   - coolcorners.org → [Your Cluster IP]"
echo ""
echo "2. Wait 2-5 minutes for certificates to be issued"
echo ""
echo "3. Test your endpoints:"
echo "   - Frontend: https://coolcorners.org"
echo "   - Backend:  https://coolcorners.org/api"
echo "   - Keycloak: https://coolcorners.org/keycloak"
echo "   - ArgoCD:   https://coolcorners.org/argocd"
echo ""
echo "4. Monitor certificate status with:"
echo "   kubectl get certificate -A"
echo ""
echo "=========================================="
