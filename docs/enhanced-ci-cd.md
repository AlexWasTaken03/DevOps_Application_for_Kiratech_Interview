# Pipeline CI/CD Avanzata

Questo documento descrive l'architettura avanzata della pipeline CI/CD implementata per l'Applicazione DevOps.

## Componenti della Pipeline CI

La pipeline di Integrazione Continua consiste in diversi workflow che vengono eseguiti automaticamente per garantire la qualità del codice e la sicurezza:

### 1. Pipeline CI Principale (`ci.yml`)

- **Linting Terraform**: Controllo del formato, inizializzazione e validazione
- **Linting Ansible**: Validazione dei playbook utilizzando ansible-lint
- **Linting Chart Helm**: Validazione dei chart Helm
- **Linting Script Shell**: Validazione degli script shell utilizzando ShellCheck

### 2. Scansione di Sicurezza (`security-scan.yml`)

- **Sicurezza Terraform** (tfsec): Scansiona il codice Terraform per problemi di sicurezza
- **Scansione Immagini Docker** (Trivy): Scansiona Dockerfile e immagini container
- **Scansione Manifest Kubernetes** (kubesec): Analizza i manifest Kubernetes per verificare le best practice di sicurezza
- **Rilevamento Segreti** (TruffleHog): Cerca credenziali e segreti trapelati

### 3. Test dell'Infrastruttura (`infrastructure-tests.yml`)

- **Piano Terraform**: Genera e convalida i piani di esecuzione Terraform
- **Validazione Template Helm**: Renderizza e convalida i template Helm
- **Modalità Check Ansible**: Esegue i playbook Ansible in modalità check per validare la sintassi

## Pipeline CD

La pipeline di Distribuzione Continua (`cd.yml`) offre un processo di deployment robusto:

### Caratteristiche Principali

1. **Deployment Specifici per Ambiente**: 
   - Supporto per ambienti di staging e produzione
   - Gate di approvazione separati per ciascun ambiente

2. **Test Completi**:
   - Validazione pre-deployment di tutte le risorse
   - Scansione di sicurezza prima del deployment
   - Verifica della distribuzione dei pod

3. **Visibilità del Deployment**:
   - Anteprima dettagliata del deployment
   - Report riepilogativo delle modifiche
   - Artefatti di deployment per audit

4. **Workflow di Approvazione**:
   - Approvazione manuale richiesta prima del deployment
   - Gate di approvazione specifici per ambiente

5. **Sistema di Notifiche**:
   - Notifiche sullo stato del deployment
   - Notifiche nei commenti delle PR sulla disponibilità del deployment

## Architettura della Pipeline

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│ Commit Codice │────▶│ Workflow CI   │────▶│ Linting       │
└───────────────┘     └───────────────┘     └───────────────┘
                            │                       │
                            ▼                       ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│ Tag Release   │────▶│ Workflow CD   │────▶│ Validazione   │
└───────────────┘     └───────────────┘     └───────────────┘
                            │                       │
                            ▼                       ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│ Trigger       │────▶│ Test Pre-     │────▶│ Scansione di  │
│ Manuale       │     │ deployment    │     │ Sicurezza     │
└───────────────┘     └───────────────┘     └───────────────┘
                            │                       │
                            ▼                       ▼
                     ┌───────────────┐      ┌───────────────┐
                     │ Gate di       │◀─────│ Simulazione   │
                     │ Approvazione  │      │ Deployment    │
                     └───────────────┘      └───────────────┘
                            │
                            ▼
                     ┌───────────────┐
                     │ Deployment    │
                     └───────────────┘
                            │
                            ▼
                     ┌───────────────┐
                     │ Verifica      │
                     └───────────────┘
```

## Utilizzo

### Esecuzione della Pipeline CI

La pipeline CI viene eseguita automaticamente su:
- Ogni push al branch main
- Ogni pull request al branch main

### Attivazione della Pipeline CD

La pipeline CD può essere attivata:
1. Automaticamente quando il codice viene pushato al branch `release`
2. Manualmente tramite l'interfaccia GitHub Actions con queste opzioni:
   - Selezione dell'ambiente (staging/produzione)
   - Opzione di salto dei test per correzioni di emergenza

### Scansione di Sicurezza

Il workflow di scansione di sicurezza viene eseguito:
- Ad ogni push su main
- Ad ogni pull request
- Settimanalmente secondo una pianificazione (domenica a mezzanotte)
- Su richiesta tramite trigger manuale

## Estensione della Pipeline

Per aggiungere nuovi componenti alla pipeline:

1. Per nuovi componenti dell'infrastruttura:
   - Aggiungere i relativi step di linting a `ci.yml`
   - Aggiungere la scansione di sicurezza in `security-scan.yml`
   - Includere la validazione in `infrastructure-tests.yml`

2. Per nuovi componenti dell'applicazione:
   - Aggiornare il chart Helm per includere il nuovo componente
   - Aggiungere i passaggi di deployment in `cd.yml`
   - Includere il componente nei report di deployment
