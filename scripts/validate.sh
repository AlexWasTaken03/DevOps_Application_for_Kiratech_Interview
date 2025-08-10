#!/bin/bash

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Validazione prerequisiti
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    local errors=0
    
    # Check commands
    for cmd in vagrant VBoxManage ansible terraform helm kubectl; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is not installed or not in PATH"
            errors=$((errors + 1))
        else
            version=$($cmd --version 2>/dev/null | head -1 || echo "unknown")
            log_debug "$cmd: $version"
        fi
    done
    
    # Check system resources
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 8 ]; then
        log_warn "Low RAM detected: ${total_ram}GB (recommended: 8GB+)"
    fi
    
    total_disk=$(df -BG . | awk 'NR==2{gsub(/G/, "", $4); print $4}')
    if [ "$total_disk" -lt 20 ]; then
        log_warn "Low disk space: ${total_disk}GB (recommended: 20GB+)"
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Prerequisites validation failed with $errors errors"
        return 1
    fi
    
    log_info "Prerequisites validation passed!"
    return 0
}

# Validazione configurazioni
validate_configurations() {
    log_info "Validating configurations..."
    
    # Terraform validation
    log_debug "Validating Terraform configurations..."
    cd terraform
    terraform fmt -check -recursive . || {
        log_error "Terraform formatting issues found. Run: terraform fmt -recursive ."
        return 1
    }
    terraform init -backend=false
    terraform validate || {
        log_error "Terraform configuration validation failed"
        return 1
    }
    cd ..
    
    # Ansible validation
    log_debug "Validating Ansible configurations..."
    cd ansible
    ansible-playbook --syntax-check playbooks/site.yml -i inventory/hosts.yml || {
        log_error "Ansible syntax validation failed"
        return 1
    }
    cd ..
    
    # Helm validation
    log_debug "Validating Helm charts..."
    cd helm/webapp-stack
    helm dependency update
    helm lint . || {
        log_error "Helm chart validation failed"
        return 1
    }
    helm template webapp-stack . --values values.yaml > /dev/null || {
        log_error "Helm template rendering failed"
        return 1
    }
    cd ../..
    
    log_info "Configuration validation passed!"
    return 0
}

# Validazione cluster
validate_cluster() {
    log_info "Validating Kubernetes cluster..."
    
    if [ ! -f kubeconfig ]; then
        log_warn "Kubeconfig not found. Cluster may not be deployed yet."
        return 0
    fi
    
    export KUBECONFIG=$(pwd)/kubeconfig
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    # Check nodes
    ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready ")
    total_nodes=$(kubectl get nodes --no-headers | wc -l)
    
    if [ "$ready_nodes" -ne "$total_nodes" ] || [ "$total_nodes" -ne 3 ]; then
        log_error "Expected 3 ready nodes, found $ready_nodes/$total_nodes"
        return 1
    fi
    
    log_info "Cluster validation passed! ($ready_nodes/$total_nodes nodes ready)"
    return 0
}

# Validazione applicazione
validate_application() {
    log_info "Validating application deployment..."
    
    if [ ! -f kubeconfig ]; then
        log_warn "Kubeconfig not found. Application may not be deployed yet."
        return 0
    fi
    
    export KUBECONFIG=$(pwd)/kubeconfig
    
    # Check namespace
    if ! kubectl get namespace kiratech-test &> /dev/null; then
        log_warn "Application namespace not found. Application may not be deployed yet."
        return 0
    fi
    
    # Check pods
    running_pods=$(kubectl get pods -n kiratech-test --no-headers | grep -c " Running ")
    total_pods=$(kubectl get pods -n kiratech-test --no-headers | wc -l)
    
    if [ "$running_pods" -eq 0 ]; then
        log_warn "No running pods found in kiratech-test namespace"
        return 0
    fi
    
    # Check services
    services=$(kubectl get svc -n kiratech-test --no-headers | wc -l)
    
    if [ "$services" -lt 3 ]; then
        log_warn "Expected at least 3 services, found $services"
    fi
    
    # Test application connectivity
    log_debug "Testing application connectivity..."
    if kubectl port-forward -n kiratech-test svc/webapp-stack-frontend 18080:80 &> /dev/null &
    then
        PF_PID=$!
        sleep 3
        
        if curl -f http://localhost:18080 &> /dev/null; then
            log_info "Application connectivity test passed!"
            kill $PF_PID 2>/dev/null || true
        else
            log_warn "Application not responding on HTTP"
            kill $PF_PID 2>/dev/null || true
        fi
    else
        log_warn "Could not setup port forwarding for connectivity test"
    fi
    
    log_info "Application validation completed! ($running_pods/$total_pods pods running)"
    return 0
}

# Validazione sicurezza
validate_security() {
    log_info "Validating security configurations..."
    
    if [ ! -f kubeconfig ]; then
        log_warn "Kubeconfig not found. Security validation skipped."
        return 0
    fi
    
    export KUBECONFIG=$(pwd)/kubeconfig
    
    # Check kube-bench job
    if kubectl get job kube-bench-security-scan -n kiratech-test &> /dev/null; then
        job_status=$(kubectl get job kube-bench-security-scan -n kiratech-test -o jsonpath='{.status.conditions[0].type}')
        
        if [ "$job_status" = "Complete" ]; then
            log_info "Security benchmark job completed successfully"
            
            # Show summary of results
            log_debug "Security benchmark summary:"
            kubectl logs job/kube-bench-security-scan -n kiratech-test | grep -E "^
$$
PASS
$$|^
$$
FAIL
$$|^
$$
WARN
$$" | sort | uniq -c | while read count result; do
                case $result in
                    "[PASS]") log_debug "  ✅ $count passed checks" ;;
                    "[FAIL]") log_debug "  ❌ $count failed checks" ;;
                    "[WARN]") log_debug "  ⚠️  $count warnings" ;;
                esac
            done
        else
            log_warn "Security benchmark job not completed yet"
        fi
    else
        log_warn "Security benchmark job not found"
    fi
    
    # Check network policies
    if kubectl get networkpolicy -n kiratech-test &> /dev/null; then
        np_count=$(kubectl get networkpolicy -n kiratech-test --no-headers | wc -l)
        log_debug "Network policies configured: $np_count"
    fi
    
    log_info "Security validation completed!"
    return 0
}

# Report di validazione
generate_report() {
    log_info "Generating validation report..."
    
    cat > validation-report.md << 'REPORT_EOF'
# KiraTech Kubernetes Project - Validation Report

**Generated**: $(date)
**Validator**: $(whoami)@$(hostname)

## System Information

- **OS**: $(lsb_release -d 2>/dev/null | cut -f2 || uname -a)
- **RAM**: $(free -h | awk '/^Mem:/{print $2}')
- **Disk**: $(df -h . | awk 'NR==2{print $4}') available
- **CPU**: $(nproc) cores

## Tool Versions

REPORT_EOF

    # Add tool versions to report
    for tool in vagrant VBoxManage ansible terraform helm kubectl; do
        if command -v $tool &> /dev/null; then
            version=$($tool --version 2>/dev/null | head -1 || echo "unknown")
            echo "- **$tool**: $version" >> validation-report.md
        else
            echo "- **$tool**: ❌ Not installed" >> validation-report.md
        fi
    done

    cat >> validation-report.md << 'REPORT_EOF'

## Validation Results

REPORT_EOF

    # Run validations and capture results
    if validate_prerequisites; then
        echo "- ✅ **Prerequisites**: Passed" >> validation-report.md
    else
        echo "- ❌ **Prerequisites**: Failed" >> validation-report.md
    fi

    if validate_configurations; then
        echo "- ✅ **Configurations**: Passed" >> validation-report.md
    else
        echo "- ❌ **Configurations**: Failed" >> validation-report.md
    fi

    if validate_cluster; then
        echo "- ✅ **Cluster**: Passed" >> validation-report.md
    else
        echo "- ⚠️ **Cluster**: Warning/Not Ready" >> validation-report.md
    fi

    if validate_application; then
        echo "- ✅ **Application**: Passed" >> validation-report.md
    else
        echo "- ⚠️ **Application**: Warning/Not Ready" >> validation-report.md
    fi

    if validate_security; then
        echo "- ✅ **Security**: Passed" >> validation-report.md
    else
        echo "- ⚠️ **Security**: Warning/Not Ready" >> validation-report.md
    fi

    cat >> validation-report.md << 'REPORT_EOF'

## Recommendations

- Ensure all prerequisites are installed before running setup
- Run `make setup` for complete environment deployment
- Use `make status` to monitor cluster and application health
- Check security benchmark results with `make benchmark`

REPORT_EOF

    log_info "Validation report generated: validation-report.md"
}

# Funzione principale
main() {
    log_info "KiraTech Kubernetes Project - Validation Script"
    log_info "================================================"
    
    local exit_code=0
    
    validate_prerequisites || exit_code=1
    validate_configurations || exit_code=1
    validate_cluster || exit_code=1
    validate_application || exit_code=1
    validate_security || exit_code=1
    
    generate_report
    
    log_info "================================================"
    if [ $exit_code -eq 0 ]; then
        log_info "✅ Overall validation: PASSED"
    else
        log_warn "⚠️ Overall validation: PASSED with warnings"
    fi
    log_info "Check validation-report.md for detailed results"
    log_info "================================================"
    
    return $exit_code
}

# Esegue validazione se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
