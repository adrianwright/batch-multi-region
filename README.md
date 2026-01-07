# Multi-Region Azure OpenAI Batch API with APIM

Intelligent load balancing for OpenAI Batch API across multiple Azure regions using API Management.

## The Challenge

OpenAI Batch API workflows require **files and batch jobs to exist in the same region**. Random load balancing breaks this requirement, causing batch job failures when files and jobs land in different regions.

## Architecture Approaches

### 🔴 Approach 1: Random Load Balancing (Client-Managed)

**How it works:** Each API request is independently routed to any available region. The `X-Backend-Region` header indicates which region handled the request.

```
File upload → East US 2 → X-Backend-Region: eastus2
Client stores region
Batch submit → Client specifies East US 2 ✓
```

<table>
<tr><th>✅ Pros</th><th>❌ Cons</th></tr>
<tr>
<td valign="top">

- Simple APIM configuration
- Even load distribution
- No additional dependencies
- Full client control

</td>
<td valign="top">

- Client must track regions
- Client-side logic required
- Manual region management
- Error-prone for complex workflows

</td>
</tr>
</table>

**Use when:** You have a sophisticated client that can manage region affinity, or want full control over routing decisions.

---

### 🟡 Approach 2: APIM Session Affinity

**How it works:** APIM's built-in session affinity uses cookies to route requests from the same client to the same backend.

```
File upload → East US 2 → Set-Cookie: ARRAffinity=...
Batch submit → Cookie sent → East US 2 ✓
```

<table>
<tr><th>✅ Pros</th><th>❌ Cons</th></tr>
<tr>
<td valign="top">

- No external dependencies
- Built into APIM
- Zero additional cost
- Automatic routing

</td>
<td valign="top">

- Requires cookie support
- Client must maintain session
- Cookie can expire/be lost
- Not suitable for distributed clients

</td>
</tr>
</table>

**Use when:** Single client application, controlled environment, cookie management is acceptable.

---

### 🟢 Approach 3: Redis Session Affinity (Recommended)

**How it works:** Redis cache maps file/batch IDs to regions, enabling intelligent routing independent of client session.

```
File upload → Random (East US 2) → Redis: file-123 → eastus2
Batch submit → Lookup file-123 → East US 2 ✓
Batch status → Lookup batch-456 → East US 2 ✓
```

<table>
<tr><th>✅ Pros</th><th>❌ Cons</th></tr>
<tr>
<td valign="top">

- **Works with any client**
- No session requirements
- Distributed architecture support
- ID-based routing (not client-based)
- Survives client restarts
- Load balanced across regions

</td>
<td valign="top">

- Requires Redis cache
- Additional Azure resource
- ~$15/month (Basic C0)
- Slightly more complex

</td>
</tr>
</table>

**Use when:** Multiple clients, serverless apps, distributed systems, or production workloads.

**Redis Data:**
- `backend:file-{id}` → `eastus2` or `westus3` (TTL: 24h)
- `backend:batch-{id}` → `eastus2` or `westus3` (TTL: 24h)

---

## Quick Start

### Deploy

```bash
az deployment sub create \
  --name "apim-redis-$(date +%Y%m%d%H%M%S)" \
  --location eastus \
  --template-file main.bicep
```

### Use Redis Sticky API

```bash
# Upload → Submit → Status (all route correctly)
curl -X POST "{apim}/openai-sticky/openai/files?api-version=2024-10-21" \
  -H "Ocp-Apim-Subscription-Key: {key}" \
  -F "purpose=batch" -F "file=@input.jsonl"

curl -X POST "{apim}/openai-sticky/openai/batches?api-version=2024-10-21" \
  -H "Ocp-Apim-Subscription-Key: {key}" \
  -H "Content-Type: application/json" \
  -d '{"input_file_id":"file-xxx","endpoint":"/v1/chat/completions","completion_window":"24h"}'
```

### Test

```powershell
.\test-sticky-api.ps1  # Verifies session affinity across both regions
```

## Resources

- **Diagrams:** [architecture-diagram.drawio](architecture-diagram.drawio)
- **APIM:** apim-dev-{random} (rg-apim-dev)
- **Redis:** redis-dev-{random} (Basic C0)
- **Foundries:** batch-sticky-east-us-2, batch-sticky-west-us-3 (rg-batch-sticky)

