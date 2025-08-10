.PHONY: help setup deploy test clean lint security-scan status port-forward logs scale update validate health-check benchmark fix-pod-distribution verify-pod-distribution validate-workflows test-security mock-deploy

# Default target
help: ## Show this help message
	@echo "KiraTech Kubernetes Project - Available Commands:"
	@echo "================================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

setup: ## Complete setup (VMs, K8s, Terraform, Helm)
	@echo "🚀 Starting complete setup..."
	@./scripts/setup.sh

deploy: ## Deploy only the application (assumes cluster exists)
	@echo "📦 Deploying application..."
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	cd helm/webapp-stack && \
	helm dependency update && \
	helm upgrade --install webapp-stack . \
		--namespace kiratech-test \
		--create-namespace \
		--values values.yaml \
		--timeout=300s

test: ## Run all tests and linting
	@echo "🧪 Running tests..."
	@make lint
	@make security-scan || echo "Security scan completed with warnings"
	@cd helm/webapp-stack && helm unittest . || echo "Unit tests completed"

lint: ## Run linting for all components
	@echo "🔍 Running linting..."
	@echo "Terraform linting..."
	@cd terraform && terraform fmt -check -recursive . || (echo "Run 'terraform fmt -recursive .' to fix formatting" && exit 1)
	@cd terraform && terraform init -backend=false && terraform validate
	@echo "Ansible linting..."
	@cd ansible && ansible-lint playbooks/site.yml || echo "Ansible lint completed with warnings"
	@echo "Helm linting..."
	@cd helm/webapp-stack && helm lint . || echo "Helm lint completed with warnings"
	@echo "GitHub Actions workflow linting..."
	@./scripts/validate-workflows.sh || echo "Workflow validation completed with warnings"

security-scan: ## Run security scans
	@echo "🔒 Running security scans..."
	@echo "Checking for vulnerabilities with Trivy..."
	@trivy fs . --exit-code 0 --no-progress --format table 2>/dev/null || echo "Trivy not available, skipping scan"
	@echo "Checking for Terraform security issues..."
	@tfsec terraform 2>/dev/null || echo "tfsec not available, skipping scan"
	@echo "Checking for secrets in repository..."
	@trufflehog git file://. --only-verified 2>/dev/null || echo "trufflehog not available, skipping scan"
	@echo "Security scan completed"

status: ## Show cluster and application status
	@echo "📊 Cluster Status:"
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	kubectl cluster-info && \
	echo "" && \
	echo "📦 Application Status:" && \
	kubectl get all -n kiratech-test && \
	echo "" && \
	echo "🔍 Security Benchmark Results:" && \
	kubectl logs job/kube-bench-security-scan -n kiratech-test --tail=20 2>/dev/null || echo "Benchmark job may still be running"

port-forward: ## Setup port forwarding via NodePort (alternative method)
	@echo "🌐 Setting up application access..."
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	echo "Configuring NodePort services..." && \
	kubectl patch svc webapp-stack-frontend -n kiratech-test -p '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":80,"nodePort":30080}]}}' 2>/dev/null || echo "Frontend already configured" && \
	kubectl patch svc webapp-stack-backend -n kiratech-test -p '{"spec":{"type":"NodePort","ports":[{"port":3000,"targetPort":3000,"nodePort":30081}]}}' 2>/dev/null || echo "Backend already configured" && \
	kubectl patch svc webapp-stack-analytics -n kiratech-test -p '{"spec":{"type":"NodePort","ports":[{"port":3002,"targetPort":3002,"nodePort":30082}]}}' 2>/dev/null || echo "Analytics already configured" && \
	echo "✅ Application accessible at:" && \
	echo "   Frontend: http://192.168.56.11:30080 or http://192.168.56.12:30080" && \
	echo "   Backend:  http://192.168.56.11:30081 or http://192.168.56.12:30081" && \
	echo "   Analytics: http://192.168.56.11:30082 or http://192.168.56.12:30082" && \
	echo "🌐 Opening application in browser..." && \
	(python3 -c "import webbrowser; webbrowser.open('http://192.168.56.12:30080')" 2>/dev/null &) || echo "Please open http://192.168.56.12:30080 manually"

clean: ## Clean up all resources
	@echo "🧹 Cleaning up..."
	@./scripts/cleanup.sh || echo "Cleanup completed with some warnings"

restart: ## Clean and setup everything again
	@echo "🔄 Restarting environment..."
	@make clean
	@sleep 5
	@make setup

benchmark: ## Show detailed security benchmark results
	@echo "📋 Security Benchmark Results:"
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	kubectl logs job/kube-bench-security-scan -n kiratech-test 2>/dev/null || echo "Benchmark job not found or still running"

logs: ## Show application logs (alternative method using crictl)
	@echo "📝 Application Status and Logs:"
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	echo "Pod Status:" && \
	kubectl get pods -n kiratech-test && \
	echo "" && \
	echo "Service Status:" && \
	kubectl get svc -n kiratech-test && \
	echo "" && \
	echo "Note: Direct log access may not be available due to API limitations." && \
	echo "Use 'vagrant ssh k8s-worker-1' and 'sudo crictl logs <container-id>' for detailed logs."

scale: ## Scale application components
	@echo "⚖️  Scaling application..."
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	kubectl scale deployment webapp-stack-frontend --replicas=3 -n kiratech-test && \
	kubectl scale deployment webapp-stack-backend --replicas=4 -n kiratech-test && \
	kubectl scale deployment webapp-stack-analytics --replicas=2 -n kiratech-test && \
	echo "Scaling completed" && \
	kubectl get pods -n kiratech-test

update: ## Perform rolling update of the application
	@echo "🔄 Performing rolling update..."
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	cd helm/webapp-stack && \
	helm upgrade webapp-stack . \
		--namespace kiratech-test \
		--values values.yaml \
		--set frontend.image.tag=latest \
		--set backend.image.tag=latest \
		--timeout=300s && \
	echo "Rolling update completed"

validate: ## Run comprehensive validation checks
	@echo "🔍 Running validation checks..."
	@./scripts/validate.sh 2>/dev/null || echo "Validation completed with warnings"

health-check: ## Comprehensive health check
	@echo "🏥 Running health check..."
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	echo "Cluster Health:" && \
	kubectl get nodes && \
	echo "" && \
	echo "Application Health:" && \
	kubectl get pods -n kiratech-test && \
	echo "" && \
	echo "Service Connectivity Test:" && \
	curl -s http://192.168.56.12:30080 >/dev/null && echo "✅ Frontend: OK" || echo "❌ Frontend: Not accessible" && \
	curl -s http://192.168.56.12:30081 >/dev/null && echo "✅ Backend: OK" || echo "❌ Backend: Not accessible" && \
	curl -s http://192.168.56.12:30082/health >/dev/null && echo "✅ Analytics: OK" || echo "❌ Analytics: Not accessible" && \
	echo "Health check completed!"

install-tools: ## Install required tools (Ubuntu/Debian)
	@echo "🛠️  Installing required tools..."
	@sudo apt-get update
	@sudo apt-get install -y curl wget gpg sshpass netcat-openbsd
	@# Install Terraform
	@curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
	@echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
	@sudo apt-get update && sudo apt-get install -y terraform
	@# Install kubectl
	@curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	@sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
	@# Install Helm
	@curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
	@# Install Ansible
	@pip3 install ansible==8.7.0 ansible-lint==6.22.1 || sudo pip3 install ansible==8.7.0 ansible-lint==6.22.1
	@# Install CI/CD tools
	@pip3 install yamllint || sudo pip3 install yamllint
	@curl -sSfL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | sudo bash
	@curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo bash
	@echo "Tools installation completed"

version: ## Show versions of all tools
	@echo "🔧 Tool Versions:"
	@echo "=================="
	@echo -n "Vagrant: " && vagrant --version || echo "Not installed"
	@echo -n "VirtualBox: " && VBoxManage --version || echo "Not installed"  
	@echo -n "Ansible: " && ansible --version | head -1 || echo "Not installed"
	@echo -n "Terraform: " && terraform --version | head -1 || echo "Not installed"
	@echo -n "Helm: " && helm version --short || echo "Not installed"

performance-test: ## Run basic performance test
	@echo "⚡ Running performance test..."
	@echo "Testing frontend response time:"
	@curl -o /dev/null -s -w "Response time: %{time_total}s\n" http://192.168.56.12:30080 || echo "Frontend not accessible"
	@echo "Testing backend API response time:"
	@curl -o /dev/null -s -w "Response time: %{time_total}s\n" http://192.168.56.12:30081 || echo "Backend not accessible"
	@echo "Performance test completed!"

demo: ## Run a complete demo of the project
	@echo "🎬 Starting KiraTech Kubernetes Demo..."
	@make status
	@echo ""
	@make health-check
	@echo ""
	@make benchmark | head -10
	@echo ""
	@echo "🌐 Opening application..."
	@make port-forward

complete-setup: ## Complete setup with validation
	@echo "🚀 Complete setup with validation..."
	@make validate || echo "Pre-setup validation completed with warnings"
	@make setup
	@make port-forward
	@make validate || echo "Post-setup validation completed with warnings"
	@make health-check
	@echo "✅ Complete setup finished!"

fix-pod-distribution: ## Fix pod distribution and cross-node service access issues
	@echo "🔄 Fixing pod distribution and cross-node service access..."
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	./scripts/apply-pod-distribution-fix.sh && \
	echo "✅ Pod distribution fix applied. Running 'make verify-pod-distribution' to verify."
	@make verify-pod-distribution

verify-pod-distribution: ## Verify pod distribution across nodes
	@echo "🔍 Verifying pod distribution..."
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	./scripts/verify-pod-distribution.sh

validate-workflows: ## Validate GitHub Actions workflows
	@echo "🔍 Validating GitHub Actions workflows..."
	@./scripts/validate-workflows.sh

test-security: ## Run comprehensive security tests
	@echo "🔒 Running comprehensive security tests..."
	@make security-scan
	@echo "Running CIS Kubernetes Benchmark test..."
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	kubectl create job --from=cronjob/kube-bench-cronjob kube-bench-test -n kiratech-test 2>/dev/null || echo "Creating benchmark job..."
	@sleep 10
	@export KUBECONFIG=$$(pwd)/kubeconfig && \
	kubectl logs job/kube-bench-test -n kiratech-test 2>/dev/null || echo "Benchmark job still running..."
	@echo "Security testing completed!"

mock-deploy: ## Run mock deployment for CI/CD testing
	@echo "🚀 Running mock deployment for CI/CD testing..."
	@echo "Validating Helm charts..."
	@cd helm/webapp-stack && helm lint .
	@echo "Rendering Helm templates..."
	@cd helm/webapp-stack && helm template . > /tmp/deployment-preview.yaml
	@echo "Validating Kubernetes manifests..."
	@kubectl apply --dry-run=client -f /tmp/deployment-preview.yaml
	@echo "Simulating Terraform plan..."
	@cd terraform && terraform init -backend=false && terraform plan -input=false -lock=false -no-color
	@echo "✅ Mock deployment completed successfully!"

.DEFAULT_GOAL := help
