#!/bin/bash
# Helper script for CI pipeline to check if fixes were applied

# Check for pod distribution fix
if grep -q "podAntiAffinity:" "./helm/webapp-stack/values.yaml" && grep -q "enabled: true" "./helm/webapp-stack/values.yaml"; then
  echo "✅ Pod anti-affinity is correctly enabled"
else
  echo "❌ Pod anti-affinity should be enabled in values.yaml"
  exit 1
fi

# Check for proper replica count
if grep -q "replicaCount: 2" "./helm/webapp-stack/values.yaml"; then
  echo "✅ Replica count is correctly set to 2 for high availability"
else
  echo "❌ Replica count should be set to 2 or higher for high availability"
  exit 1
fi

# Check for PDB configuration
if grep -q "podDisruptionBudget:" "./helm/webapp-stack/values.yaml" && grep -q "enabled: true" "./helm/webapp-stack/values.yaml"; then
  echo "✅ Pod Disruption Budget is correctly enabled"
else
  echo "❌ Pod Disruption Budget should be enabled for high availability"
  exit 1
fi

echo "All pod distribution checks passed!"
exit 0
