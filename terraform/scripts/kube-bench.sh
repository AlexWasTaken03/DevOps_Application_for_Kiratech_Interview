#!/bin/sh

echo "Starting Kubernetes Security Benchmark with kube-bench..."
echo "========================================================="

# Run kube-bench with output to stdout and file
kube-bench run --targets=master,node,etcd,policies 2>&1 | tee /tmp/kube-bench-results.txt

echo ""
echo "========================================================="
echo "Benchmark completed. Results saved to /tmp/kube-bench-results.txt"
echo "========================================================="

# Show summary
echo ""
echo "SECURITY BENCHMARK SUMMARY:"
echo "==========================="
grep -E "(PASS|FAIL|WARN)" /tmp/kube-bench-results.txt | head -20

exit 0
