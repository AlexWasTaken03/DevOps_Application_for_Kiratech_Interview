# Kiratech Kubernetes Project


# Kubernetes Cluster Provisioning & Application Deployment

## Scopo e Descrizione della Soluzione

Questo repository pubblico automatizza l’intero ciclo di vita di un cluster Kubernetes locale (1 master + 2 worker) su Virtual Machines, il setup delle risorse e policy tramite Terraform, il benchmark di sicu### Funzionalità di Sicurezza e Alta Disponibilità

### 1. CIS Kubernetes Benchmark
Controlli automatici conformità sicurezza tramite kube-bench. Il report completo è disponibile in `terraform/validation-report.md`.

### 2. Pod Distribution e High Availability
Per garantire alta disponibilità e resilienza, ho implementato:
- **Pod Anti-Affinity**: Distribuzione dei pod su nodi diversi
- **Pod Disruption Budget**: Protezione durante manutenzione cluster
- **Multi-replica Deployment**: Frontend, Backend e Analytics eseguiti con replica count=2
- **CI Automatico**: Verifica automatica della configurazione tramite la pipeline CI

Per visualizzare i dettagli dell'implementazione, vedere `helm/pod-distribution-fix-report.md`.

Per applicare e verificare la configurazione di alta disponibilità, ho utilizzato kube-bench e il deployment di un’applicazione multi-servizio tramite Helm. Tutto il codice è modulare, riutilizzabile e validato da una pipeline CI su GitHub Actions.

---

## Scelte Tecniche

### Provisioning VM

- **Vagrant + VirtualBox**: Definizione dichiarativa delle VM, provisioning automatico e portabilità. Ideale per ambienti di sviluppo/test.
- **Ansible**: Playbook e ruoli modulari per installazione e configurazione di Docker, Kubernetes, utenti e SSH.

### Benchmark di Sicurezza

- **kube-bench (CIS Kubernetes Benchmark)**: Deploy come Kubernetes Job tramite Terraform, raccolta automatica dei risultati nei log pod.

### Moduli e Codice Open-Source

- **Ansible**: Ruoli separati per master, worker, common setup. Playbook principale: `ansible/playbooks/site.yml`.
- **Terraform**: Moduli per namespace, job, policy, e risorse cluster. File principali: `terraform/main.tf`, `terraform/outputs.tf`.
- **Helm**: Chart parametrico per frontend, backend, cache. Directory: `helm/webapp-stack/`.

### Pipeline CI/CD

- **CI Pipeline**: Workflow automatico su ogni push che esegue:
  - Linting Terraform (`terraform fmt`, `terraform validate`)
  - Linting Ansible (`ansible-lint`)
  - Linting Helm (`helm lint`)
  - Linting Shell Scripts (`shellcheck`)
  - Scansioni di sicurezza dell'infrastruttura
  - Test di validazione delle configurazioni

- **CD Pipeline**: Pipeline di deployment completa con:
  - Trigger automatico sul branch release
  - Approvazione manuale prima del deployment
  - Simulazione di deployment per validazione
  - Report dettagliati pre e post deployment
  - Supporto per ambienti staging e production

- **Pipeline di Sicurezza**: Scansione automatica di:
  - Codice Terraform (tfsec)
  - Immagini Docker (Trivy)
  - Manifesti Kubernetes (kubesec)
  - Secrets nel repository (TruffleHog)

Per una documentazione dettagliata della pipeline CI/CD, vedere [Enhanced CI/CD Pipeline](docs/enhanced-ci-cd.md).

### Pod Distribution e High Availability

- **Pod Anti-Affinity**: Distribuzione dei pod su nodi diversi per migliorare resilienza e disponibilità.
- **Pod Disruption Budget**: Protezione contro interruzioni volontarie durante la manutenzione del cluster.
- **Cross-Node Communication**: Configurazione ottimizzata per comunicazione tra servizi su nodi diversi.

---
### Architecture

```
                Application Layer
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Frontend   │     │   Backend   │     │  Analytics  │
│ (Port 30080)│<--->│ (Port 30081)│<--->│ (Port 30082)│
└─────────────┘     └─────────────┘     └─────────────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │   Redis Cache   │
                  │   (Internal)    │
                  └─────────────────┘
                           │
                           ▼
       ┌─────────────────────────────────────┐
       │         Kubernetes Cluster          │
       │       (k8s-master + 2 workers)      │
       └─────────────────────────────────────┘
                           │
                           ▼
       ┌─────────────────────────────────────┐
       │      Infrastructure (Vagrant)       │
       │         192.168.56.10-12            │
       └─────────────────────────────────────┘
```

---
### Prerequisiti

- [Vagrant](https://www.vagrantup.com/)
- [VirtualBox](https://www.virtualbox.org/)
- [Ansible](https://www.ansible.com/)
- [Terraform](https://www.terraform.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)
- [Git](https://git-scm.com/)
- [Make](https://www.gnu.org/software/make/)
- [Docker](https://www.docker.com/)
- [Node.js](https://nodejs.org/) (per l'applicazione)
- [npm](https://www.npmjs.com/) (per l'applicazione)
### Versioni degli Strumenti
- Vagrant: 2.2.19
- VirtualBox: 6.1.30
- Ansible: 2.9.27
- Terraform: 1.0.11
- kubectl: 1.21.0
- Helm: 3.5.4
- Docker: 20.10.7
- Node.js: 14.x
- npm: 6.x
### Versioni dei Componenti dell'Applicazione
- Frontend: Modern Bootstrap 5.3 Dashboard with Chart.js
- Backend: Node.js Express 14.x
- Cache: Redis 6.x
- Analytics: Node.js 20.x service for metrics tracking
### Versioni dei Benchmark di Sicurezza
- kube-bench: 0.5.0 (CIS Kubernetes Benchmark v1.5.0)
### Versioni dei Moduli Riutilizzabili
- Ansible Roles: v1.0.0
- Terraform Modules: v1.0.0
- Helm Charts: v1.0.0
### Versioni dei Test e Validazione
- Terraform: `terraform fmt`, `tflint`
- Ansible: `ansible-lint`
- Helm: `helm lint`

### System Requirements

    RAM: Minimum 8GB (16GB recommended)
    CPU: 4+ cores
    Disk: 20GB free space
    OS: Linux, macOS, or Windows with WSL2

### Avvio Rapido

1. Clona il Repository

```bash

git clone <repository-url>
cd kiratech-kubernetes-project
```

2. Installa gli Strumenti Richiesti (Ubuntu/Debian)

```bash
make install-tools
```

3. Verifica le Versioni degli Strumenti

```bash
make version
``` 

4. Setup Completo (Un Solo Comando!)

```bash

make complete-setup

Questo singolo comando:

    Crea e configura le VM
    Configura il cluster Kubernetes
    Effettua il deploy dell'applicazione
    Configura la rete
    Esegue i benchmark di sicurezza
    Apre l'applicazione nel browser
```

5. Accedi alla Tua Applicazione

    Frontend Dashboard: http://192.168.56.12:30080
    Backend API: http://192.168.56.11:30081
    Analytics Service: http://192.168.56.11:30082/health


### Comandi Disponibili

Usa make help per vedere tutti i comandi disponibili:

### Comandi Essenziali:

make setup	Setup completo (VM, K8s, Terraform, Helm)

make deploy	Deploy solo dell'applicazione

make status	Mostra stato cluster e applicazione

make port-forward	Configura accesso applicazione

make clean	Pulisce tutte le risorse

make fix-pod-distribution  Risolve problemi di distribuzione pod

make verify-pod-distribution  Verifica distribuzione pod tra nodi

### Comandi di Sviluppo

make test	Esegue tutti i test e il linting

make lint	Esegue il linting per tutti i componenti

make validate	Esegue validazione completa

make health-check	Health check completo

### Comandi Operativi

make scale	Scala i componenti dell'applicazione

make update	Esegue aggiornamento rolling

make logs	Mostra i log dell'applicazione

make benchmark	Mostra risultati benchmark sicurezza

### Comandi Utility

make demo	Esegue demo completa

make performance-test	Esegue test prestazioni base

make security-scan	Esegue scansioni sicurezza

make restart	Pulisce e configura tutto


## Istruzioni per Provisioning e Deployment manuale

### 1. Provisioning delle VM

```bash
cd vagrant
vagrant up
```

### 2. Configurazione Cluster Kubernetes

```bash
cd ../ansible
ansible-playbook -i inventory playbooks/site.yml
```

### 3. Provisioning Risorse Kubernetes e Benchmark Sicurezza

```bash
cd ../terraform
terraform init
terraform apply
```

Il job kube-bench viene eseguito automaticamente. I risultati sono disponibili nei log del pod e nel report [`terraform/validation-report.md`](terraform/validation-report.md).

### 4. Deployment Applicazione Helm-based

```bash
cd ../helm/webapp-stack
helm upgrade --install webapp-stack . --namespace kiratech-test --create-namespace
```

L’applicazione è accessibile via browser tramite il NodePort esposto (vedi output di `kubectl get svc -n kiratech-test`).

### 5. Pipeline CI

La pipeline CI su GitHub Actions esegue automaticamente:
- Linting Terraform (`terraform fmt`, `tflint`)
- Linting Ansible (`ansible-lint`)
- Linting Helm (`helm lint`)

---

## Struttura del Repository

- `vagrant/` : Vagrantfile per definizione VM
- `ansible/` : Playbook, ruoli modulari, inventario
- `terraform/` : Moduli, job kube-bench, report validazione
- `helm/webapp-stack/` : Chart Helm multi-servizio (frontend, backend, cache)
- `.github/workflows/` : Pipeline CI

---

## Evidenza Benchmark di Sicurezza

Esempio di output kube-bench:

```
== Summary node ==
Total Pass: 20, Total Fail: 2, Total Warn: 1, Total Info: 5

[FAIL] 1.1.1 Ensure that the API server pod specification file permissions are set to 644 or more restrictive
[FAIL] 1.1.2 Ensure that the API server pod specification file ownership is set to root:root
...
```

Il report completo è disponibile in [`terraform/validation-report.md`](terraform/validation-report.md).

## Risultati Distribuzione Pod

La configurazione di pod anti-affinity garantisce che i pod siano distribuiti su diversi nodi worker:

```
Deployment: webapp-stack-frontend
  Node k8s-worker-1: 1 pods
  Node k8s-worker-2: 1 pods
-----------------------------------
Deployment: webapp-stack-backend
  Node k8s-worker-1: 1 pods
  Node k8s-worker-2: 1 pods
-----------------------------------
Deployment: webapp-stack-analytics
  Node k8s-worker-1: 1 pods
  Node k8s-worker-2: 1 pods
```

Per i dettagli completi, vedere [`helm/pod-distribution-fix-report.md`](helm/pod-distribution-fix-report.md).

---

## Versionamento e Moduli Riutilizzabili

Il codice è versionato su GitHub, organizzato in moduli riutilizzabili per Ansible, Terraform e Helm. Le modifiche sono tracciate tramite commit e pull request. La struttura modulare consente estensione e riutilizzo per altri cluster o applicazioni.

### Testing
Esegui Tutti i Test

```bash

make test

Comandi Test Individuali
```

```bash

make lint           # Controlli qualità codice
make security-scan  # Scansione vulnerabilità sicurezza
make validate      # Validazione infrastruttura
make health-check  # Health check applicazione
```

### Configurazione

Personalizzare il Deployment

    Valori Helm: Modifica helm/webapp-stack/values.yaml
    Infrastruttura: Modifica configurazioni in terraform/
    Impostazioni VM: Aggiorna Vagrantfile
    Playbook Ansible: Personalizza ansible/playbooks/

### Variabili d'Ambiente

```bash

export KUBECONFIG=$(pwd)/kubeconfig  # Impostato automaticamente dai comandi
```

---

## Funzionalità di Sicurezza e Alta Disponibilità

### 1. CIS Kubernetes Benchmark
Controlli automatici conformità sicurezza tramite kube-bench. Il report completo è disponibile in `terraform/validation-report.md`.

### 2. Pod Distribution e High Availability
Per garantire alta disponibilità e resilienza, abbiamo implementato:
- **Pod Anti-Affinity**: Distribuzione dei pod su nodi diversi
- **Pod Disruption Budget**: Protezione durante manutenzione cluster
- **Multi-replica Deployment**: Frontend, Backend e Analytics eseguiti con replica count=2

Per visualizzare i dettagli dell'implementazione, vedere `helm/pod-distribution-fix-report.md`.

Per applicare e verificare la configurazione di alta disponibilità:
```bash
# Applicare la configurazione di distribuzione pod
make fix-pod-distribution

# Verificare la distribuzione dei pod tra i nodi
make verify-pod-distribution
```

### 3. Network Policies e Security Context
- Segmentazione rete Kubernetes
- Controllo accesso basato sui ruoli (RBAC)
- Configurazioni sicurezza pod

### Monitoraggio e Osservabilità

    Stato Real-time: make status
    Health Check: make health-check
    Test Prestazioni: make performance-test
    Accesso Log: make logs
    Benchmark Sicurezza: make benchmark
