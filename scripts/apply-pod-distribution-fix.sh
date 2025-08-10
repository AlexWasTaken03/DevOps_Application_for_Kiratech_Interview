#!/bin/bash

# Script to apply the pod distribution and cross-node service access fixes
# This script upgrades the Helm chart with the new values

echo "Applying pod distribution and cross-node service access fixes..."

# Switch to the correct context
if [ -f "kubeconfig" ]; then
  export KUBECONFIG=$(pwd)/kubeconfig
  echo "Using kubeconfig at $(pwd)/kubeconfig"
else
  echo "Warning: kubeconfig file not found, using default kubeconfig"
fi

# Make sure we have kubectl
if ! command -v kubectl &> /dev/null; then
  echo "Error: kubectl is not installed or not in PATH"
  exit 1
fi

# Make sure we have helm
if ! command -v helm &> /dev/null; then
  echo "Error: helm is not installed or not in PATH"
  exit 1
fi

# Check if the namespace exists
if ! kubectl get namespace kiratech-test &> /dev/null; then
  echo "Creating namespace kiratech-test..."
  kubectl create namespace kiratech-test
fi

# Apply the Helm chart
echo "Upgrading Helm chart with new pod distribution settings..."
helm upgrade --install webapp-stack ./helm/webapp-stack --namespace kiratech-test

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=webapp-stack --timeout=300s -n kiratech-test

# Run the verification script
echo "Running verification script..."
./scripts/verify-pod-distribution.sh

echo "Pod distribution and cross-node service access fixes have been applied."
echo "Check the verification output above to confirm that pods are properly distributed and services can communicate."
