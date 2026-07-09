# Azure Bicep practice project

A small end-to-end web app stack, built to be deployable on an Azure free-tier
subscription while covering the Bicep concepts you'll actually use day to day:
modules, parameters, variables, outputs, secure params, dependencies via
`outputs`, RBAC role assignments, and subscription-scope deployment.

## What gets deployed

| Resource | SKU / tier | Free tier note |
|---|---|---|
| Resource group | - | free |
| Virtual network + 2 subnets | - | free |
| App Service Plan + Web App | F1 (Free) | 60 CPU min/day free |
| Storage account | Standard_LRS | ~5GB free for 12 months on a new subscription |
| Key Vault | Standard | first 10k operations/month free |
| SQL Server + Database | GP_S_Gen5_1 with `useFreeLimit` | 100,000 vCore-seconds & 32GB free/month (1 per subscription) |
| Log Analytics workspace + App Insights | PerGB2018 | 5GB/day ingestion free |

## Project structure

```
azure-bicep-practice/
├── main.bicep                  # orchestrator, subscription-scoped
├── main.parameters.json        # parameter values
└── modules/
    ├── network.bicep           # VNet + app/data subnets
    ├── logAnalytics.bicep      # Log Analytics + App Insights
    ├── storageAccount.bicep    # storage account + blob container
    ├── keyVault.bicep          # Key Vault (RBAC auth)
    ├── sqlDatabase.bicep       # SQL server + free-tier database
    └── appService.bicep        # App Service plan (F1) + web app
```

## Prerequisites

- Azure CLI installed and logged in: `az login`
- Bicep CLI (bundled with recent Azure CLI): `az bicep install`
- A free-tier Azure subscription

## Deploy

Subscription-scope deployment needs a `--location` for the deployment
metadata itself (separate from the resource `location` parameter):

```bash
az deployment sub create \
  --name bicep-practice-deploy \
  --location eastus \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --parameters sqlAdminPassword='<choose a strong password>'
```

Passing the password on the command line (not stored in the parameters file)
keeps it out of source control — this is worth practicing as a habit.

## Validate before deploying

```bash
az deployment sub what-if \
  --location eastus \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --parameters sqlAdminPassword='<placeholder>'
```

`what-if` shows exactly what will be created/changed without deploying —
use this every time while learning.

## Clean up

Free tier resources still count toward subscription quotas (e.g. the free
SQL database is one per subscription), so delete the resource group when
you're done experimenting:

```bash
az group delete --name rg-bicepprac-dev --yes --no-wait
```

## Suggested learning path

1. **Deploy as-is** and confirm the web app URL responds (default site).
2. **Add a parameter** — e.g. make the App Service SKU configurable, add a
   `@allowed` list of SKUs.
3. **Add a loop** — turn the single storage container into a `for` loop
   deploying multiple containers (`logs`, `uploads`, `backups`).
4. **Add conditional deployment** — use a `deployMonitoring bool` param to
   make the Log Analytics module optional with an `if` condition.
5. **Add an output-driven connection** — pass the SQL connection string into
   the web app's app settings as a Key Vault reference instead of plain text.
6. **Split into a Bicep registry module** — publish `network.bicep` to a
   private ACR-backed Bicep registry and reference it remotely.
7. **Add a GitHub Actions workflow** that runs `az deployment sub what-if`
   on pull requests and `az deployment sub create` on merge to `main` — this
   turns the project into an actual "learn DevOps" exercise, not just IaC.

## Notes

- Key Vault names are capped at 24 characters, and `modules/keyVault.bicep`
  truncates to fit — with `projectName = "3-tier-web-app"` this trims most
  of the random suffix from the vault name. That's fine for a solo learning
  subscription, but if you ever hit a global name collision, shorten
  `projectName` or edit that module to hash instead of truncate.
- `useFreeLimit` on the SQL database only works if your subscription hasn't
  already used its one free database elsewhere — check the Azure portal's
  SQL free offer page if deployment fails on that resource.
- The Key Vault role assignment is scoped to the resource group for
  simplicity; in a production template you'd scope it to the vault itself.
- Region availability for free-tier SQL and free App Service quota can vary
  — if `eastus` fails, try `westus2` or `centralus`.
