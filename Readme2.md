# Kiratech Kubernetes Project
## 📋 Scopo e Descrizione della Soluzione

Questo repository pubblico automatizza l'intero ciclo di vita di un cluster Kubernetes locale (1 master + 2 worker) su Virtual Machines, il setup delle risorse e policy tramite Terraform, il benchmark di sicurezza CIS con kube-bench e il deployment di un'applicazione multi-servizio tramite Helm. Tutto il codice è modulare, riutilizzabile e validato da una pipeline CI su GitHub Actions.

### Caratteristiche Principali

- **🚀 Setup Automatizzato**: Un singolo comando per deploy completo
- **🔒 Security-First**: Benchmark CIS Kubernetes integrati
- **📊 Multi-Service App**: Frontend, Backend, Analytics con Redis cache
- **🏗️ Infrastruttura come Codice**: Terraform + Ansible + Helm
- **⚡ Alta Disponibilità**: Pod anti-affinity e disruption budgets
- **🔄 CI/CD Pipeline**: Validazione automatica con GitHub Actions

---

## 🏗️ Architettura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │    │   Analytics     │
│   (Port 30080)  │────│   (Port 30081)  │────│   (Port 30082)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                      │
         └───────────────────────┼──────────────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │     Redis Cache          │
                    │     (Internal)           │
                    └──────────────────────────┘
                                 │
    ┌─────────────────────────────────────────────────┐
    │              Kubernetes Cluster                 │
    │           (k8s-master + 2 workers)              │
    └─────────────────────────────────────────────────┘
                                 │
    ┌─────────────────────────────────────────────────┐
    │          Infrastructure (Vagrant)               │
    │             192.168.56.10-12                    │
    └─────────────────────────────────────────────────┘
```

---

## 🛠️ Scelte Tecniche - Rationale Decisionale

### **Provisioning VM: Vagrant + VirtualBox**

**Vagrant** è stato scelto per la sua capacità di definire l'infrastruttura come codice attraverso il Vagrantfile, garantendo reproducibilità completa dell'ambiente. Elimina il problema "funziona sulla mia macchina" permettendo a qualsiasi sviluppatore di ricreare l'identico ambiente con un singolo comando. La gestione automatica del ciclo di vita delle VM, il supporto per snapshot/rollback e la configurazione networking automatica lo rendono superiore ad approcci manuali.

**VirtualBox** è stato preferito ad alternative come VMware o Hyper-V per diversi fattori critici: è completamente gratuito e open source, offre supporto cross-platform universale, ha integrazione nativa con Vagrant senza plugin aggiuntivi, e fornisce isolamento completo a livello hypervisor. Sebbene Docker Desktop sia più leggero, non offre lo stesso livello di isolamento necessario per un ambiente Kubernetes multi-nodo realistico.

### **Configuration Management: Ansible**

**Ansible** è stato scelto rispetto a Chef, Puppet o SaltStack per la sua architettura agentless che elimina la necessità di installare software sui nodi target, riducendo la superficie di attacco e semplificando la manutenzione. La sintassi YAML è intuitiva e accessibile, abbassando drasticamente la curva di apprendimento rispetto ai DSL proprietari di Chef o Puppet. 

Il modello push garantisce controllo centralizzato ed esecuzione immediata, a differenza del modello pull di Chef/Puppet che introduce latenza. L'idempotenza nativa assicura che esecuzioni multiple producano sempre lo stesso risultato, mentre la struttura modulare dei ruoli permette riusabilità e manutenibilità ottimali.

### **Infrastructure as Code: Terraform**

**Terraform** eccelle nella gestione dichiarativa dello stato dell'infrastruttura Kubernetes, offrendo vantaggi sostanziali rispetto all'uso diretto di kubectl e YAML. Il tracking automatico delle dipendenze elimina errori di ordinamento, mentre il planning pre-esecuzione permette di visualizzare le modifiche prima dell'applicazione.

La gestione dello stato remoto consente collaborazione team senza conflitti, e la drift detection identifica modifiche manuali non autorizzate. I moduli riusabili promuovono standardizzazione e best practices, mentre il supporto multi-provider facilita eventuali migrazioni cloud future. Rispetto a soluzioni come Pulumi, Terraform ha un ecosistema più maturo e maggiore adozione enterprise.

### **Security Benchmarking: kube-bench**

**kube-bench** implementa gli standard CIS (Center for Internet Security) Kubernetes Benchmark, rappresentando il riferimento de facto del settore per la valutazione della sicurezza. È sviluppato e mantenuto dalla CNCF community, garantendo neutralità vendor e aggiornamenti costanti.

L'integrazione come Kubernetes Job permette automazione completa e schedulazione flessibile, mentre l'esecuzione in ambiente isolato assicura che i controlli non interferiscano con i workload applicativi. Rispetto a soluzioni proprietarie o script custom, offre copertura completa e standardizzata dei controlli di sicurezza più critici.

### **Application Packaging: Helm**

**Helm** è stato scelto come package manager Kubernetes per le sue capacità di templating avanzate che permettono parametrizzazione e riusabilità dei chart. Il release management automatico offre versionamento, rollback atomici e cronologia completa delle modifiche, funzionalità assenti in approcci basati su kubectl plain o Kustomize.

La gestione delle dipendenze e il supporto multi-environment attraverso values files separati semplificano deployment su diversi stage. L'ecosistema vasto di chart community e le hook pre/post-deployment offrono flessibilità operativa superiore. Rispetto a Kustomize, Helm fornisce maggiore potenza di templating e gestione del ciclo di vita applicativo.

### **Pipeline CI/CD: GitHub Actions**

**GitHub Actions** offre integrazione native con il repository senza necessità di configurazioni esterne o servizi aggiuntivi. Il modello event-driven permette automazione sofisticata basata su push, pull request e releases, mentre il marketplace fornisce azioni predefinite per la maggior parte delle esigenze.

Rispetto a Jenkins, elimina la complessità di gestione dell'infrastruttura CI, mentre rispetto a GitLab CI o Azure DevOps, offre costi inferiori per progetti open source e integrazione più stretta con l'ecosistema GitHub. I matrix builds permettono test paralleli su multiple versioni e ambienti.

### **High Availability: Pod Anti-Affinity e PDB**

**Pod Anti-Affinity** è stato implementato per garantire distribuzione intelligente dei pod su nodi diversi, eliminando single point of failure e migliorando resilienza. Le regole preferredDuringScheduling offrono flessibilità, mentre requiredDuringScheduling fornisce garanzie hard per ambienti critici.

**Pod Disruption Budgets** proteggono l'applicazione durante operazioni di manutenzione cluster, assicurando che un numero minimo di repliche rimanga sempre disponibile. Questa combinazione crea un'architettura resiliente che tollera guasti di nodo e maintenance window senza interruzioni di servizio.

### **Filosofia Architetturale**

Le scelte tecniche seguono principi di **progressive complexity** (iniziare semplice, evolvere verso complessità), **industry standards** (utilizzare best practice consolidate), **community-driven selection** (preferire tool con community attive) e **operational excellence** (ottimizzare per operazioni day-2). Ogni tool è stato valutato non solo per funzionalità immediate ma anche per learning path, skills transferability e evoluzione futura verso ambienti cloud-native.

---

## ⚡ Avvio Rapido

### 📋 Prerequisiti

#### Tools Richiesti
- [Vagrant](https://www.vagrantup.com/) (2.2.19+)
- [VirtualBox](https://www.virtualbox.org/) (6.1.30+)
- [Ansible](https://www.ansible.com/) (2.9.27+)
- [Terraform](https://www.terraform.io/) (1.0.11+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (1.21.0+)
- [Helm](https://helm.sh/) (3.5.4+)
- [Git](https://git-scm.com/)
- [Make](https://www.gnu.org/software/make/)
- [Docker](https://www.docker.com/) (20.10.7+)
- [Node.js](https://nodejs.org/) (14.x+)
- [npm](https://www.npmjs.com/) (6.x+)

#### Requisiti di Sistema
- **RAM**: Minimo 8GB (16GB raccomandati)
- **CPU**: 4+ core
- **Disk**: 20GB spazio libero
- **OS**: Linux, macOS, o Windows con WSL2

### 🚀 Setup in 5 Passi

#### 1. Clona il Repository
```bash
git clone <repository-url>
cd kiratech-kubernetes-project
```

#### 2. Installa gli Strumenti Richiesti (Ubuntu/Debian)
```bash
make install-tools
```

#### 3. Verifica le Versioni degli Strumenti
```bash
make version
```

#### 4. Setup Completo (Un Solo Comando!)
```bash
make complete-setup
```

Questo singolo comando:
- ✅ Crea e configura le VM
- ✅ Configura il cluster Kubernetes
- ✅ Effettua il deploy dell'applicazione
- ✅ Configura la rete
- ✅ Esegue i benchmark di sicurezza
- ✅ Apre l'applicazione nel browser

#### 5. Accedi alla Tua Applicazione
- **Frontend Dashboard**: http://192.168.56.12:30080
- **Backend API**: http://192.168.56.11:30081
- **Analytics Service**: http://192.168.56.11:30082/health

---

## 🎯 Comandi Disponibili

### Comandi Essenziali
| Comando | Descrizione |
|---------|-------------|
| `make setup` | Setup completo (VM, K8s, Terraform, Helm) |
| `make deploy` | Deploy solo dell'applicazione |
| `make status` | Mostra stato cluster e applicazione |
| `make port-forward` | Configura accesso applicazione |
| `make clean` | Pulisce tutte le risorse |
| `make fix-pod-distribution` | Risolve problemi di distribuzione pod |
| `make verify-pod-distribution` | Verifica distribuzione pod tra nodi |

### Comandi di Sviluppo
| Comando | Descrizione |
|---------|-------------|
| `make test` | Esegue tutti i test e il linting |
| `make lint` | Esegue il linting per tutti i componenti |
| `make validate` | Esegue validazione completa |
| `make health-check` | Health check completo |

### Comandi Operativi
| Comando | Descrizione |
|---------|-------------|
| `make scale` | Scala i componenti dell'applicazione |
| `make update` | Esegue aggiornamento rolling |
| `make logs` | Mostra i log dell'applicazione |
| `make benchmark` | Mostra risultati benchmark sicurezza |

### Comandi Utility
| Comando | Descrizione |
|---------|-------------|
| `make demo` | Esegue demo completa |
| `make performance-test` | Esegue test prestazioni base |
| `make security-scan` | Esegue scansioni sicurezza |
| `make restart` | Pulisce e configura tutto |

Usa `make help` per vedere tutti i comandi disponibili.

---

## 🔧 Setup Manuale (Opzionale)

Se preferisci eseguire i passaggi manualmente:

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

### 4. Deployment Applicazione Helm-based
```bash
cd ../helm/webapp-stack
helm upgrade --install webapp-stack . --namespace kiratech-test --create-namespace
```

---

## 📁 Struttura del Repository

```
├── vagrant/                    # Vagrantfile per definizione VM
├── ansible/                    # Playbook, ruoli modulari, inventario
│   ├── playbooks/
│   ├── roles/
│   └── inventory/
├── terraform/                  # Moduli, job kube-bench, report validazione
│   ├── modules/
│   ├── main.tf
│   └── validation-report.md
├── helm/webapp-stack/          # Chart Helm multi-servizio
│   ├── templates/
│   ├── values.yaml
│   └── Chart.yaml
├── .github/workflows/          # Pipeline CI
├── Makefile                    # Automazione comandi
└── README.md                   # Questa documentazione
```

---

## 🔒 Funzionalità di Sicurezza e Alta Disponibilità

### 1. CIS Kubernetes Benchmark
Controlli automatici conformità sicurezza tramite kube-bench. Il report completo è disponibile in `terraform/validation-report.md`.

**Esempio Output:**
```
== Summary node ==
Total Pass: 20, Total Fail: 2, Total Warn: 1, Total Info: 5

[FAIL] 1.1.1 Ensure that the API server pod specification file permissions are set to 644 or more restrictive
[FAIL] 1.1.2 Ensure that the API server pod specification file ownership is set to root:root
```

### 2. Pod Distribution e High Availability
Per garantire alta disponibilità e resilienza:

- **Pod Anti-Affinity**: Distribuzione dei pod su nodi diversi
- **Pod Disruption Budget**: Protezione durante manutenzione cluster
- **Multi-replica Deployment**: Frontend, Backend e Analytics con replica count=2

**Risultati Distribuzione Pod:**
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

Per i dettagli completi, vedere `helm/pod-distribution-fix-report.md`.

### 3. Network Policies e Security Context
- Segmentazione rete Kubernetes
- Controllo accesso basato sui ruoli (RBAC)
- Configurazioni sicurezza pod

---

## 🧪 Testing e Validazione

### Esegui Tutti i Test
```bash
make test
```

### Comandi Test Individuali
```bash
make lint           # Controlli qualità codice
make security-scan  # Scansione vulnerabilità sicurezza
make validate      # Validazione infrastruttura
make health-check  # Health check applicazione
```

### Pipeline CI
La pipeline CI su GitHub Actions esegue automaticamente:
- ✅ Linting Terraform (`terraform fmt`, `tflint`)
- ✅ Linting Ansible (`ansible-lint`)
- ✅ Linting Helm (`helm lint`)

---

## ⚙️ Configurazione

### Personalizzare il Deployment
- **Valori Helm**: Modifica `helm/webapp-stack/values.yaml`
- **Infrastruttura**: Modifica configurazioni in `terraform/`
- **Impostazioni VM**: Aggiorna `Vagrantfile`
- **Playbook Ansible**: Personalizza `ansible/playbooks/`

### Variabili d'Ambiente
```bash
export KUBECONFIG=$(pwd)/kubeconfig  # Impostato automaticamente dai comandi
```

---

## 📊 Monitoraggio e Osservabilità

| Comando | Descrizione |
|---------|-------------|
| `make status` | Stato real-time cluster e applicazione |
| `make health-check` | Health check completo sistema |
| `make performance-test` | Test prestazioni base |
| `make logs` | Accesso centralizzato ai log |
| `make benchmark` | Risultati benchmark sicurezza |

---

## 📦 Versioni dei Componenti

### Strumenti di Base
- **Vagrant**: 2.2.19
- **VirtualBox**: 6.1.30
- **Ansible**: 2.9.27
- **Terraform**: 1.0.11
- **kubectl**: 1.21.0
- **Helm**: 3.5.4
- **Docker**: 20.10.7
- **Node.js**: 14.x
- **npm**: 6.x

### Componenti dell'Applicazione
- **Frontend**: Modern Bootstrap 5.3 Dashboard with Chart.js
- **Backend**: Node.js Express 14.x
- **Cache**: Redis 6.x
- **Analytics**: Node.js 20.x service for metrics tracking

### Benchmark di Sicurezza
- **kube-bench**: 0.5.0 (CIS Kubernetes Benchmark v1.5.0)

### Moduli Riutilizzabili
- **Ansible Roles**: v1.0.0
- **Terraform Modules**: v1.0.0
- **Helm Charts**: v1.0.0

---

## 🚀 Utilizzo Avanzato

### Scaling e Performance
```bash
# Scala l'applicazione
make scale

# Esegue test di performance
make performance-test

# Monitora le risorse
kubectl top nodes
kubectl top pods -n kiratech-test
```

### Troubleshooting
```bash
# Verifica stato generale
make status

# Debug pod distribution
make verify-pod-distribution

# Visualizza log dettagliati
make logs

# Health check completo
make health-check
```

### Demo e Presentazioni
```bash
# Esegue una demo completa
make demo

# Reset completo per nuova demo
make restart
```

---
## 🛠️ Sviluppo

### Sviluppo Locale
```bash
# Setup ambiente di sviluppo
make setup

# Esegui test prima del commit
make test

# Linting e validazione
make lint
make validate
```