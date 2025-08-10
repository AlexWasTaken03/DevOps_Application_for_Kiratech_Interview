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

# Controlla prerequisiti
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    for tool in vagrant VBoxManage ansible terraform helm kubectl; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing tools: ${missing_tools[*]}"
        log_error "Please install missing tools or run: make install-tools"
        exit 1
    fi
    
    log_info "All prerequisites are satisfied!"
}

# Provisiona le VM con Vagrant
provision_vms() {
    log_info "Provisioning virtual machines with Vagrant..."
    
    cd vagrant
    
    # Distrugge VM esistenti se necessario
    if vagrant status | grep -q "running\|saved\|poweroff"; then
        log_warn "Existing VMs found. Destroying them..."
        vagrant destroy -f
    fi
    
    # Avvia le nuove VM
    vagrant up
    
    cd ..
    
    log_info "Virtual machines provisioned successfully!"
}

# Setup SSH keys per Ansible
setup_ssh_keys() {
    log_info "Setting up SSH keys for Ansible..."
    
    # Esegue lo script di setup SSH
    ./scripts/setup-ssh.sh
    
    log_info "SSH keys configured successfully!"
}

# Configura cluster Kubernetes con Ansible
setup_kubernetes() {
    log_info "Setting up Kubernetes cluster with Ansible..."
    
    cd ansible
    
    # Verifica la sintassi del playbook
    ansible-playbook --syntax-check -i inventory/hosts.yml playbooks/site.yml
    
    # Esegue il playbook principale
    ansible-playbook -i inventory/hosts.yml playbooks/site.yml -v
    
    cd ..
    
    # Copia kubeconfig dal master
    log_info "Copying kubeconfig from master node..."
    scp -i ~/.ssh/ansible_key -o StrictHostKeyChecking=no vagrant@192.168.56.10:/home/vagrant/.kube/config ./kubeconfig
    
    # Verifica che il cluster sia funzionante
    export KUBECONFIG=$(pwd)/kubeconfig
    
    log_info "Waiting for cluster to be ready..."
    sleep 30
    
    # Attende che tutti i nodi siano pronti
    local retry_count=0
    local max_retries=30
    
    while [ $retry_count -lt $max_retries ]; do
        ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready " || echo "0")
        total_nodes=$(kubectl get nodes --no-headers | wc -l || echo "0")
        
        if [ "$ready_nodes" -eq 3 ] && [ "$total_nodes" -eq 3 ]; then
            log_info "All nodes are ready ($ready_nodes/$total_nodes)"
            break
        else
            log_info "Waiting for nodes to be ready ($ready_nodes/$total_nodes)..."
            sleep 10
            retry_count=$((retry_count + 1))
        fi
    done
    
    if [ $retry_count -eq $max_retries ]; then
        log_error "Timeout waiting for cluster to be ready"
        exit 1
    fi
    
    log_info "Kubernetes cluster setup completed!"
}

# Applica configurazioni Terraform
apply_terraform() {
    log_info "Applying Terraform configurations..."
    
    cd terraform
    
    # Inizializza Terraform
    terraform init
    
    # Verifica la configurazione
    terraform validate
    
    # Applica le configurazioni
    terraform plan
    terraform apply -auto-approve
    
    cd ..
    
    log_info "Terraform configurations applied successfully!"
}

# Deploy applicazione con Helm
deploy_application() {
    log_info "Deploying application with Helm..."
    
    # Configura kubectl
    export KUBECONFIG=$(pwd)/kubeconfig
    
    # Verifica che il cluster sia accessibile
    kubectl cluster-info
    
    # Aggiunge repository Bitnami
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    cd helm/webapp-stack
    
    # Aggiorna le dipendenze
    helm dependency update
    
    # Verifica il chart
    helm lint .
    
    # Deploy in namespace kiratech-test
    helm upgrade --install webapp-stack . \
        --namespace kiratech-test \
        --create-namespace \
        --values values.yaml \
        --wait --timeout=600s
    
    cd ../..
    
    log_info "Application deployed successfully!"
}

# Verifica deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    export KUBECONFIG=$(pwd)/kubeconfig
    
    # Controlla cluster
    log_info "Cluster information:"
    kubectl cluster-info
    
    # Controlla nodi
    log_info "Node status:"
    kubectl get nodes -o wide
    
    # Controlla pods nel namespace kiratech-test
    log_info "Application pods:"
    kubectl get pods -n kiratech-test -o wide
    
    # Controlla servizi
    log_info "Services:"
    kubectl get svc -n kiratech-test
    
    # Controlla job kube-bench (potrebbe ancora essere in esecuzione)
    log_info "Security benchmark status:"
    kubectl get job -n kiratech-test
}

# Mostra summary finale
show_summary() {
    log_info "=============================================="
    log_info "🎉 KiraTech Kubernetes Project Setup Complete!"
    log_info "=============================================="
    log_info ""
    log_info "📋 Quick Access Commands:"
    log_info "  Frontend Dashboard:  http://192.168.56.11:30080/"
    log_info "  Backend API:         http://192.168.56.11:30081/"
    log_info "  Analytics Service:   http://192.168.56.11:30082/health"
    log_info "  Cluster Status:      make status"
    log_info "  Application Logs:    make logs"
    log_info "  Security Benchmark:  make benchmark"
    log_info ""
    log_info "🔧 Management Commands:"
    log_info "  Scale Application:   make scale"
    log_info "  Rolling Update:      make update"
    log_info "  Health Check:        make health-check"
    log_info "  Clean Environment:   make clean"
    log_info ""
    log_info "📚 Documentation:"
    log_info "  Full Commands:       make help"
    log_info "  Project README:      cat README.md"
    log_info "  Validation Report:   make validate"
    log_info ""
    log_info "=============================================="
}

# Funzione principale
main() {
    log_info "Starting KiraTech Kubernetes Project Setup..."
    log_info "=============================================="
    
    check_prerequisites
    provision_vms
    setup_ssh_keys
    setup_kubernetes
    apply_terraform
    deploy_application
    verify_deployment
    show_summary
}

# Trap per cleanup in caso di errore
trap 'log_error "Setup failed. Check logs above for details."' ERR

# Esegue setup se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
