# Dev Container Configuration

This dev container provides a complete development environment for the Azure APIM Multi-Region project with all necessary tools pre-installed.

## Included Tools

- **Azure CLI** - Latest version with Bicep extension
- **Bicep CLI** - For Azure Infrastructure as Code
- **Terraform** - For alternative IaC approach
- **PowerShell** - For Azure automation scripts
- **Git** - Version control
- **GitHub CLI** - GitHub integration

## VS Code Extensions

- Azure Bicep
- Azure Resource Groups
- Terraform
- PowerShell
- Azure Account
- GitHub Copilot

## Usage

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) in VS Code
3. Open this repository in VS Code
4. Click "Reopen in Container" when prompted, or run command: **Dev Containers: Reopen in Container**
5. Wait for the container to build (first time only)

## Azure Authentication

Your local Azure CLI credentials are automatically mounted into the container. If you haven't logged in yet:

```bash
az login
az account set --subscription <your-subscription-id>
```

## Deploy Infrastructure

```bash
# Deploy with Bicep
cd bicep
az deployment sub create --location eastus --template-file main.bicep --parameters main.dev.bicepparam

# Future: Deploy with Terraform
cd terraform
terraform init
terraform plan
terraform apply
```
