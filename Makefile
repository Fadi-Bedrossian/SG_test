.PHONY: help install lock test lint up down k8s-build tf-fmt tf-validate

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

install: ## Install dependencies for api and frontend
	cd api && npm install
	cd frontend && npm install

lock: install ## Generate package-lock.json files (commit them so CI uses `npm ci`)
	@echo "Commit api/package-lock.json and frontend/package-lock.json"

lint: ## Lint both apps
	cd api && npm run lint
	cd frontend && npm run lint

test: ## Unit tests for both apps
	cd api && npm test
	cd frontend && npm test

up: ## Run the full stack locally on http://localhost:8080
	docker compose up --build

down: ## Stop the local stack and delete its data
	docker compose down -v

k8s-build: ## Render both Kustomize overlays
	kustomize build k8s/overlays/dev
	kustomize build k8s/overlays/prod

tf-fmt: ## Format Terraform
	terraform -chdir=infra/terraform fmt -recursive

tf-validate: ## Validate Terraform without a backend
	terraform -chdir=infra/terraform init -backend=false
	terraform -chdir=infra/terraform validate
