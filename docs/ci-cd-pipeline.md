# CI/CD Pipeline Documentation

This document describes the CI/CD pipeline implemented in this project.

## CI Pipeline

The Continuous Integration pipeline runs automatically on every push to the `main` branch and on all pull requests. Its primary purpose is to validate code quality and ensure that all components meet the project's standards.

### CI Pipeline Steps

1. **Terraform Validation**
   - Format check using `terraform fmt`
   - Configuration validation using `terraform validate`
   - No actual infrastructure changes are made

2. **Ansible Validation**
   - Linting playbooks with `ansible-lint`
   - Checking for best practices and potential issues

3. **Helm Chart Validation**
   - Linting charts with `helm lint`
   - Ensuring charts follow best practices

4. **Shell Script Validation**
   - Analyzing shell scripts with `shellcheck`
   - Identifying common errors and bugs

### Running the CI Pipeline Locally

You can run the CI checks locally before pushing your changes:

```bash
# For Terraform
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate

# For Ansible
cd ansible
ansible-lint playbooks/site.yml

# For Helm
cd helm/webapp-stack
helm lint .

# For Shell Scripts
shellcheck scripts/*.sh
```

## CD Pipeline

The Continuous Deployment pipeline is triggered either:
- Automatically on pushes to the `release` branch
- Manually through the GitHub Actions interface

### CD Pipeline Steps

1. **Build and Validate**
   - Generating validation reports
   - Preparing deployment artifacts

2. **Simulate Deployment**
   - Testing Helm chart rendering with `helm template`
   - Validating infrastructure changes (simulated)

3. **Deployment** (Manual approval required)
   - Deploying to the selected environment (staging/production)
   - Post-deployment validation

## Pipeline Configuration

The pipeline configuration is stored in `.github/workflows/`:
- `ci.yml` - CI pipeline configuration
- `cd.yml` - CD pipeline configuration

## Best Practices

1. Always run CI checks locally before pushing changes
2. Review pipeline logs for any warnings, even if the pipeline succeeds
3. Keep the CI pipeline fast by optimizing steps and using caching
4. Use descriptive commit messages to make the pipeline history more useful
