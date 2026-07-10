# Security

## Reporting a vulnerability

This is a personal learning project, not a production service. If you spot a
security issue in the Bicep templates (e.g. an overly-broad RBAC scope, a
resource left publicly accessible, etc.), please open a GitHub issue on this
repo describing the problem.

## Secrets and credentials

- **Never commit real secrets.** `main.parameters.json` intentionally ships
  with a placeholder value for `sqlAdminPassword` — always override it at
  deploy time with `--parameters sqlAdminPassword='...'` (see the README).
  If you ever do commit a real password, rotate it immediately in the Azure
  Portal (SQL Server > Reset password) and scrub it from git history.
- `sqlAdminPassword` is marked `@secure()` in [main.bicep](main.bicep), so
  Azure won't log or display it in deployment output — but it is still your
  responsibility to keep it out of shell history and source control.
- Prefer running deployments from **Azure Cloud Shell** or a local terminal
  you trust over shared/VM environments — command-line arguments (including
  `sqlAdminPassword=...`) can be visible in shell history or process lists
  on multi-user machines.

## Known scope trade-offs in this template

These are deliberate simplifications for a learning project — call them out
if you fork this for anything real:

- **Key Vault RBAC role assignment is scoped to the resource group**, not the
  vault itself ([modules/keyVault.bicep](modules/keyVault.bicep)). In
  production, scope this to the vault to follow least privilege.
- **SQL Server firewall allows all Azure services** (`AllowAzureServices`
  rule) rather than being locked to specific IPs/VNets.
- **No private endpoints** — Storage, Key Vault, and SQL are reachable over
  their public endpoints (network access rules aside). This is a free-tier
  learning stack; production workloads should use Private Link.
- **App Service is on the Free F1 tier**, which does not support custom
  domains with TLS or several other production security features.

## Reducing exposure after experimenting

Delete the resource group when you're done (see README "Clean up") — this
removes all deployed resources, including the SQL Server/database that
otherwise stays reachable and could accrue security-relevant configuration
drift over time if left running.
