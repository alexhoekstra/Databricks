# Databricks Infrastructure as Code with Terraform

This repository contains Infrastructure as Code (IaC) assets used to provision, configure, and manage Databricks environments using Terraform. The project emphasizes repeatable deployments, secure secret management, and containerized tooling to support local development and CI/CD workflows.

## Overview

The goal of this repository is to provide a consistent and automated approach for deploying and managing Databricks resources using Terraform. By defining infrastructure as code, environments can be version controlled, reviewed, and deployed in a predictable manner.

The repository leverages:

* **Terraform** for infrastructure provisioning
* **Databricks Terraform Provider** for workspace and platform configuration
* **Docker** for portable development and deployment environments
* **HashiCorp Vault** for centralized secret management
* **Ubuntu-based containers** for standardized execution environments

Terraform is used as the primary automation framework for deploying and managing Databricks resources, following Infrastructure as Code best practices. The Databricks Terraform Provider enables management of workspace objects, jobs, clusters, permissions, secret scopes, Unity Catalog components, and other platform resources.

---

## Architecture

## Architecture

```text
┌─────────────────────────────────────────────┐
│            Developer Workstation            │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│           Self-Hosted Docker Stack          │
├─────────────────────────────────────────────┤
│ Ubuntu + Terraform Container                │
│  • Terraform CLI                            │
│  • Databricks CLI                           │
│  • Git                                      │
│                                             │
│ HashiCorp Vault Container                   │
│  • Secrets Management                       │
│  • Token Storage                            │
│  • Credential Management                    │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│                 Terraform                   │
├─────────────────────────────────────────────┤
│ Providers                                   │
│  • Databricks Provider                      │
│  • Vault Provider                           │
│  • Cloud Provider (Azure/AWS/GCP)           │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│            Databricks Platform              │
├─────────────────────────────────────────────┤
│ Workspaces                                  │
│ Clusters                                    │
│ Jobs & Workflows                            │
│ Unity Catalog                               │
│ Permissions & Access Controls               │
│ Secret Scopes                               │
└─────────────────────────────────────────────┘
```

### Infrastructure Components

#### Docker Containers

The repository uses self-hosted Docker containers to provide a consistent and repeatable deployment environment.

**Ubuntu + Terraform Container**

The Terraform container serves as the primary Infrastructure as Code execution environment and includes:

* Ubuntu operating system
* Terraform CLI
* Databricks CLI
* Git
* Supporting deployment utilities

This container is used to execute Terraform plans and deployments against Databricks and supporting cloud infrastructure.

**HashiCorp Vault Container**

A dedicated Vault container provides centralized secret management for the platform.

Vault stores and manages:

* Databricks Personal Access Tokens (PATs)
* Service Principal credentials
* Cloud provider credentials
* API keys
* Environment-specific secrets

By hosting Vault within the Docker environment, infrastructure deployments can securely retrieve secrets at runtime without exposing credentials in source control.

---

## Terraform and Databricks

Terraform serves as the automation and orchestration layer for all infrastructure deployments. The repository leverages multiple Terraform providers to manage both infrastructure resources and secure credential retrieval.

### Terraform Providers

**Databricks Provider**

Used to provision and manage Databricks resources including:

* Workspaces
* Clusters
* Jobs and Workflows
* Notebooks
* Secret Scopes
* Unity Catalog Objects
* User and Group Management
* Permissions and Access Controls

**HashiCorp Vault Provider**

Used to securely retrieve secrets from Vault during Terraform execution.

Examples include:

* Databricks authentication tokens
* Service Principal credentials
* Cloud platform credentials
* Environment configuration values

The Vault provider allows Terraform to consume secrets dynamically without storing sensitive information in code or state files where possible.

**Cloud Infrastructure Provider**

Depending on the target environment, Terraform may also leverage:

* AzureRM Provider
* AWS Provider
* Google Provider

These providers manage the underlying cloud infrastructure that supports Databricks deployments.

### Deployment Flow

```text
Developer
    │
    ▼
Terraform Container
    │
    ├── Retrieves credentials from Vault
    │
    ▼
Terraform Providers
    │
    ├── Vault Provider
    ├── Databricks Provider
    └── Cloud Provider
    │
    ▼
Databricks Platform
```

This architecture ensures that infrastructure provisioning, configuration management, and secret retrieval are fully automated, repeatable, and secure.

---

## Repository Objectives

This repository is designed to:

* Automate Databricks infrastructure deployment
* Standardize environment configuration
* Eliminate manual provisioning steps
* Securely manage credentials and secrets
* Enable repeatable deployments across environments
* Support local development through containerized tooling

---

## Terraform and Databricks

Terraform serves as the deployment engine for all infrastructure components. The Databricks Terraform Provider enables infrastructure teams to define Databricks resources as code and manage them alongside cloud infrastructure resources.

Typical resources managed through Terraform include:

* Databricks Workspaces
* Clusters
* Jobs and Workflows
* Notebooks
* Secret Scopes
* User and Group Access
* Permissions and RBAC
* Unity Catalog Objects
* Storage Integrations
* Service Principals

Using Terraform provides:

* Version-controlled infrastructure
* Consistent deployments
* Automated provisioning
* Environment promotion strategies
* Simplified disaster recovery

---

## Containerized Tooling

To ensure consistency across development, testing, and deployment environments, the repository uses self-hosted Docker containers.

### Ubuntu + Terraform Container

A lightweight Ubuntu-based container is used as the primary Terraform execution environment.

Features include:

* Ubuntu operating system
* Terraform CLI installed
* Databricks CLI support
* Git integration
* CI/CD-friendly execution environment
* Consistent deployment experience across developers and pipelines

Benefits:

* No local Terraform installation required
* Eliminates version drift
* Reproducible infrastructure deployments
* Easy integration with GitHub Actions and other automation platforms

Example usage:

```bash
docker compose up -d terraform

docker exec -it terraform bash

terraform init
terraform plan
terraform apply
```

---

### Ubuntu + HashiCorp Vault Container

A dedicated Vault container provides centralized secret management for infrastructure deployments.

Vault is used to securely store:

* Databricks Personal Access Tokens
* Service Principal credentials
* Cloud provider credentials
* API keys
* Environment-specific secrets

Benefits include:

* Centralized secret management
* Reduced credential sprawl
* Improved security posture
* Secret rotation support
* Separation of infrastructure code from sensitive data

Rather than storing credentials directly in Terraform code or source control, Terraform can retrieve secrets from Vault at deployment time.

Example workflow:

```text
Vault
   │
   ▼
Terraform
   │
   ▼
Databricks Resources
```

This approach aligns with Infrastructure as Code security best practices by keeping secrets external to the codebase.

---

## Development Workflow

### 1. Start Containers

```bash
docker compose up -d
```

### 2. Authenticate

Retrieve required credentials from Vault.

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review Changes

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

### 6. Verify Deployment

Validate resources within the Databricks workspace.

---

## Security

Security is a core design principle of this repository.

Key controls include:

* Secrets stored in HashiCorp Vault
* No hardcoded credentials
* Infrastructure defined through code reviews
* Repeatable and auditable deployments
* Containerized execution environments
* Separation of code and secrets

---

## CI/CD Integration

The repository is designed to support automated deployments through CI/CD pipelines.

Typical pipeline stages include:

1. Source Control Commit
2. Terraform Validation
3. Terraform Plan
4. Approval Gate
5. Terraform Apply
6. Post-Deployment Validation

Containerized tooling ensures the same Terraform runtime is used locally and within automation pipelines.

---

## Benefits

* Infrastructure as Code for Databricks
* Consistent and repeatable deployments
* Secure secret management with Vault
* Containerized development environment
* Reduced configuration drift
* Simplified onboarding for new team members
* Improved auditability and governance

---

## References

* Databricks Terraform Provider Documentation
* Databricks Terraform Examples Repository
* Databricks Security Reference Architecture for Terraform
