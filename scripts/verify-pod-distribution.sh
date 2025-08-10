#!/bin/bash

# Script to verify pod distribution across Kubernetes nodes
echo "Checking pod distribution across nodes..."

# Get all nodes in the cluster
NODES=$(kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers)
NODE_COUNT=$(echo "$NODES" | wc -l)

echo "Found $NODE_COUNT nodes in the cluster"
echo "-----------------------------------"

# Check deployments in our application
DEPLOYMENTS=$(kubectl get deployments -n kiratech-test -o custom-columns=NAME:.metadata.name --no-headers)

echo "Checking distribution for deployments:"
for DEPLOYMENT in $DEPLOYMENTS; do
  echo "Deployment: $DEPLOYMENT"
  
  # Get pod distribution by node
  PODS=$(kubectl get pods -n kiratech-test -l app.kubernetes.io/component=${DEPLOYMENT#webapp-stack-} -o wide)
  
  # Count pods per node
  for NODE in $NODES; do
    POD_COUNT=$(echo "$PODS" | grep "$NODE" | wc -l)
    echo "  Node $NODE: $POD_COUNT pods"
  done
  
  echo "-----------------------------------"
done

# Check services connectivity
echo "Checking service connectivity..."

# Check service connectivity using port-forward
echo "Testing service connectivity..."

# Test backend service health
echo "Testing backend service health..."
BACKEND_SERVICE=$(kubectl get svc -n kiratech-test webapp-stack-backend -o jsonpath='{.spec.ports[0].nodePort}')
if [ -n "$BACKEND_SERVICE" ]; then
  echo "Backend service is available on NodePort $BACKEND_SERVICE"
  # Test backend service health
  echo "Accessing backend service on NodePort..."
  # Use port-forward to test connectivity to backend
  kubectl port-forward svc/webapp-stack-backend -n kiratech-test 3000:3000 >/dev/null 2>&1 &
  PF_PID=$!
  sleep 2
  curl -s http://localhost:3000/health || echo "Backend health check failed"
  kill $PF_PID
else
  echo "Backend service not found"
fi

# Test redis connectivity
echo "Testing redis connectivity..."
REDIS_PODS=$(kubectl get pods -n kiratech-test -l app.kubernetes.io/component=redis -o jsonpath='{.items[*].metadata.name}')
if [ -n "$REDIS_PODS" ]; then
  echo "Redis pod(s) found: $REDIS_PODS"
  # Test connectivity to redis using port-forward
  echo "Testing connectivity to redis service..."
  kubectl port-forward svc/webapp-stack-redis -n kiratech-test 6379:6379 >/dev/null 2>&1 &
  PF_PID=$!
  sleep 2
  nc -zv localhost 6379 || echo "Redis connectivity test failed"
  kill $PF_PID
else
  echo "No redis pods found"
fi

echo "-----------------------------------"
echo "Testing completed."
