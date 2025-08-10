#!/bin/bash

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

cleanup_helm() {
    log_info "Removing Helm deployments..."
    
    if [ -f kubeconfig ]; then
        export KUBECONFIG=$(pwd)/kubeconfig
        helm uninstall webapp-stack -n kiratech-test || log_warn "Helm release may not exist"
        kubectl delete namespace kiratech-test || log_warn "Namespace may not exist"
    fi
}

cleanup_terraform() {
    log_info "Destroying Terraform resources..."
    
    cd terraform
    terraform destroy -auto-approve || log_warn "Some Terraform resources may not exist"
    cd ..
}

cleanup_vms() {
    log_info "Destroying virtual machines..."
    
    cd vagrant
    vagrant destroy -f
    cd ..
}

cleanup_files() {
    log_info "Cleaning up generated files..."
    
    rm -f kubeconfig
    rm -f join_command.sh
    rm -f ansible/join_command.sh
    rm -rf terraform/.terraform
    rm -f terraform/terraform.tfstate*
    rm -rf terraform/.terraform.lock.hcl
    rm -rf vagrant/.vagrant
}

stop_port_forwarding() {
    log_info "Stopping any port forwarding processes..."
    
    # Trova e termina processi kubectl port-forward
    pkill -f "kubectl port-forward" || log_warn "No port-forward processes found"
}

main() {
    log_info "Starting cleanup process..."
    log_info "=========================="
    
    stop_port_forwarding
    cleanup_helm
    cleanup_terraform
    cleanup_vms
    cleanup_files
    
    log_info "=========================="
    log_info "✅ Cleanup completed successfully!"
    log_info "All resources have been removed."
    log_info "=========================="
}

# Esegue cleanup se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
