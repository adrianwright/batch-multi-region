# Terraform Infrastructure for Multi-Region Batch API

This Terraform configuration deploys the same infrastructure as the Bicep templates, creating an API Management service that fronts Azure AI Foundry batch APIs with multi-region support and session affinity.

## Architecture

- **API Management (APIM)**: Central gateway with 3 API variants
  - Standard Batch API: Random load balancing across regions
  - Sticky Batch API: Redis-based region affinity for batch workflows
  - Realtime/Chat API: Session-based affinity for conversational workloads
- **Redis Cache**: External cache for session/batch affinity storage
- **Managed Identity**: APIM uses system-assigned identity to authenticate to foundries
- **Role Assignments**: APIM granted Cognitive Services OpenAI User role on foundries

## Prerequisites

- Terraform >= 1.0
- Azure CLI authenticated (`az login`)
- Existing Azure AI Foundry resources in regions (East US 2, West US 3)
- Appropriate Azure subscription permissions

## Module Structure

```
terraform/
├── main.tf                          # Root configuration
├── variables.tf                     # Input variables
├── outputs.tf                       # Output values
├── versions.tf                      # Provider versions
├── terraform.tfvars.example         # Example variables
└── modules/
    ├── redis/                       # Redis cache module
    ├── apim/                        # API Management + backends
    ├── apim-apis/                   # Standard batch API operations
    ├── apim-sticky-apis/            # Sticky batch + realtime APIs
    ├── apim-redis-config/           # Redis cache configuration
    └── role-assignments/            # RBAC assignments
```

## Usage

1. **Copy example variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars** with your values:
   ```hcl
   subscription_id              = "your-subscription-id"
   environment                  = "dev"
   location                     = "eastus"
   publisher_name               = "Your Organization"
   publisher_email              = "admin@yourorg.com"
   foundry_resource_group_name  = "rg-batch-sticky"
   foundry_east_us_2_name       = "batch-sticky-east-us-2"
   foundry_west_us_3_name       = "batch-sticky-west-us-3"
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Review plan**:
   ```bash
   terraform plan
   ```

5. **Deploy**:
   ```bash
   terraform apply
   ```

## Outputs

After deployment, Terraform provides:

- `apim_gateway_url`: APIM gateway endpoint
- `batch_api_path`: Path for standard batch API (`/openai`)
- `sticky_batch_api_path`: Path for sticky batch API (`/openai-sticky`)
- `realtime_chat_api_path`: Path for realtime/chat API (`/openai-realtime`)
- `redis_hostname`: Redis cache hostname

## API Endpoints

### Standard Batch API (`/openai`)
Random load balancing across regions:
- `POST /openai/files` - Upload file
- `POST /openai/batches` - Submit batch
- `GET /openai/batches/{batch_id}` - Get batch status
- `POST /openai/batches/{batch_id}/cancel` - Cancel batch
- `GET /openai/batches` - List batches
- `GET /openai/files` - List files
- `GET /openai/files/{file_id}` - Get file
- `DELETE /openai/files/{file_id}` - Delete file
- `GET /openai/files/{file_id}/content` - Download file

### Sticky Batch API (`/openai-sticky`)
Redis-based affinity (file → batch → same region):
- `POST /openai-sticky/files` - Upload file (stores region in Redis)
- `POST /openai-sticky/batches` - Submit batch (routes to file's region)
- `GET /openai-sticky/batches/{batch_id}` - Get batch (routes to batch's region)

### Realtime/Chat API (`/openai-realtime`)
Session-based affinity:
- `POST /openai-realtime/responses` - Azure Responses API
- `POST /openai-realtime/chat/completions` - Chat completions
- `POST /openai-realtime/embeddings` - Embeddings

## Authentication

All APIs require:
- **Subscription Key**: APIM subscription key (header: `Ocp-Apim-Subscription-Key`)
- **Backend Auth**: APIM uses managed identity to authenticate to foundries

## Clean Up

```bash
terraform destroy
```

## Differences from Bicep

- **Backend Pools**: Terraform's `azurerm_api_management_backend` doesn't natively support pool types. The current implementation uses individual backends with policy-based routing.
- **Resource Naming**: Uses `sha256` hash for uniqueness instead of `uniqueString()`.
- **External Cache**: Redis cache configuration uses `azurerm_api_management_redis_cache` resource.

## Notes

- APIM Developer SKU is used (not for production)
- Redis Basic C0 tier (minimal cost for testing)
- 24-hour TTL on Redis cache entries
- Policies use APIM policy expressions for routing logic
