#!/bin/bash

set -e

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $1"
}

# Genera chiavi SSH per Ansible se non esistono
setup_ssh_keys() {
    if [ ! -f ~/.ssh/ansible_key ]; then
        log_info "Generating SSH key pair for Ansible..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible_key -N "" -C "ansible@kiratech"
    else
        log_info "SSH key pair already exists"
    fi
}

# Attende che le VM siano completamente avviate
wait_for_vms() {
    log_info "Waiting for VMs to be fully ready..."
    
    local max_attempts=60
    local attempt=0
    
    for ip in 192.168.56.10 192.168.56.11 192.168.56.12; do
        log_info "Waiting for $ip to be accessible..."
        
        attempt=0
        while [ $attempt -lt $max_attempts ]; do
            if nc -z -w5 $ip 22 2>/dev/null; then
                log_info "$ip is responding on SSH port"
                break
            else
                log_info "Attempt $((attempt + 1))/$max_attempts: $ip not ready yet..."
                sleep 5
                attempt=$((attempt + 1))
            fi
        done
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Timeout waiting for $ip to be ready"
            return 1
        fi
    done
    
    # Attesa aggiuntiva per essere sicuri che SSH sia completamente configurato
    log_info "Waiting additional 30 seconds for SSH services to stabilize..."
    sleep 30
}

# Configura l'accesso SSH per ogni VM
configure_ssh_access() {
    for ip in 192.168.56.10 192.168.56.11 192.168.56.12; do
        log_info "Configuring SSH access for $ip..."
        
        # Rimuove eventuali chiavi precedenti
        ssh-keygen -R $ip 2>/dev/null || true
        
        # Prova prima con l'utente vagrant (default di Vagrant)
        log_info "Setting up SSH for vagrant user on $ip..."
        if sshpass -p 'vagrant' ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/ansible_key.pub vagrant@$ip 2>/dev/null; then
            log_info "SSH key copied successfully for vagrant@$ip"
        else
            log_warn "Failed to copy SSH key for vagrant@$ip, trying alternative method..."
            
            # Metodo alternativo: copia manualmente la chiave
            sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=no vagrant@$ip "
                mkdir -p ~/.ssh
                chmod 700 ~/.ssh
                echo '$(cat ~/.ssh/ansible_key.pub)' >> ~/.ssh/authorized_keys
                chmod 600 ~/.ssh/authorized_keys
                sort ~/.ssh/authorized_keys | uniq > ~/.ssh/authorized_keys.tmp
                mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys
            " || log_error "Failed to setup SSH for $ip"
        fi
        
        # Configura anche per l'utente ansible
        log_info "Setting up SSH for ansible user on $ip..."
        sshpass -p 'ansible' ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/ansible_key.pub ansible@$ip 2>/dev/null || {
            log_warn "Direct SSH copy failed for ansible@$ip, using vagrant as bridge..."
            
            # Usa vagrant come ponte per configurare ansible
            sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=no vagrant@$ip "
                sudo mkdir -p /home/ansible/.ssh
                sudo chmod 700 /home/ansible/.ssh
                echo '$(cat ~/.ssh/ansible_key.pub)' | sudo tee -a /home/ansible/.ssh/authorized_keys
                sudo chmod 600 /home/ansible/.ssh/authorized_keys
                sudo chown -R ansible:ansible /home/ansible/.ssh
                sudo sort /home/ansible/.ssh/authorized_keys | sudo uniq > /tmp/ak && sudo mv /tmp/ak /home/ansible/.ssh/authorized_keys
            " || log_error "Failed to setup SSH for ansible@$ip"
        }
        
        # Testa la connessione
        if ssh -i ~/.ssh/ansible_key -o StrictHostKeyChecking=no -o ConnectTimeout=5 ansible@$ip 'echo "SSH test successful"' >/dev/null 2>&1; then
            log_info "✅ SSH connection test passed for ansible@$ip"
        else
            log_warn "⚠️  SSH connection test failed for ansible@$ip, but continuing..."
        fi
    done
}

# Funzione principale
main() {
    log_info "Setting up SSH access for Ansible..."
    
    setup_ssh_keys
    wait_for_vms
    configure_ssh_access
    
    log_info "SSH setup completed successfully!"
    
    # Test finale di connettività
    log_info "Running final connectivity test..."
    cd ansible
    if ansible all -i inventory/hosts.yml -m ping --private-key ~/.ssh/ansible_key; then
        log_info "✅ All nodes are reachable via Ansible!"
    else
        log_warn "⚠️  Some nodes may not be reachable. Check manually with:"
        log_warn "    cd ansible && ansible all -i inventory/hosts.yml -m ping"
    fi
    cd ..
}

# Esegue setup se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
