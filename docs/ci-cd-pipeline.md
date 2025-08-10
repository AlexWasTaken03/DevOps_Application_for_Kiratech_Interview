# Documentazione Pipeline CI/CD

Questo documento descrive la pipeline CI/CD implementata in questo progetto.

## Pipeline CI

La pipeline di Integrazione Continua viene eseguita automaticamente ad ogni push sul branch `main` e su tutte le pull request. Il suo scopo principale è validare la qualità del codice e assicurare che tutti i componenti soddisfino gli standard del progetto.

### Passaggi della Pipeline CI

1. **Validazione Terraform**
   - Controllo del formato utilizzando `terraform fmt`
   - Validazione della configurazione utilizzando `terraform validate`
   - Non vengono apportate modifiche effettive all'infrastruttura

2. **Validazione Ansible**
   - Linting dei playbook con `ansible-lint`
   - Verifica delle best practice e potenziali problemi

3. **Validazione Chart Helm**
   - Linting dei chart con `helm lint`
   - Garanzia che i chart seguano le best practice

4. **Validazione Script Shell**
   - Analisi degli script shell con `shellcheck`
   - Identificazione di errori e bug comuni

### Esecuzione Locale della Pipeline CI

Puoi eseguire i controlli CI localmente prima di pushare le tue modifiche:

```bash
# Per Terraform
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate

# Per Ansible
cd ansible
ansible-lint playbooks/site.yml

# Per Helm
cd helm/webapp-stack
helm lint .

# Per Script Shell
shellcheck scripts/*.sh
```

## Pipeline CD

La pipeline di Distribuzione Continua viene attivata:
- Automaticamente sui push al branch `release`
- Manualmente tramite l'interfaccia di GitHub Actions

### Passaggi della Pipeline CD

1. **Build e Validazione**
   - Generazione di report di validazione
   - Preparazione degli artefatti di deployment

2. **Simulazione di Deployment**
   - Test di rendering del chart Helm con `helm template`
   - Validazione delle modifiche all'infrastruttura (simulate)

3. **Deployment** (Richiesta approvazione manuale)
   - Deployment nell'ambiente selezionato (staging/produzione)
   - Validazione post-deployment

## Configurazione della Pipeline

La configurazione della pipeline è memorizzata in `.github/workflows/`:
- `ci.yml` - Configurazione della pipeline CI
- `cd.yml` - Configurazione della pipeline CD

## Best Practice

1. Eseguire sempre i controlli CI localmente prima di pushare le modifiche
2. Rivedere i log della pipeline per eventuali avvisi, anche se la pipeline ha successo
3. Mantenere la pipeline CI veloce ottimizzando i passaggi e utilizzando il caching
4. Utilizzare messaggi di commit descrittivi per rendere la cronologia della pipeline più utile
