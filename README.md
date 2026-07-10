# 3-Tier-Web-App

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
- A free-tier Azure subscription (create one at
  [azure.microsoft.com/free](https://azure.microsoft.com/free) if you don't
  have one yet — `az login` will report "No subscriptions found" if you
  don't)

## Where to run these commands

Two options — pick whichever gives you the least friction:

**Option A — Azure Cloud Shell (recommended, avoids local login issues)**

Open [portal.azure.com](https://portal.azure.com), sign in, and click the
Cloud Shell icon (`>_`) in the top toolbar. Choose **Bash**. You're already
authenticated as your Azure account, so `az login` isn't needed. Clone the
repo there:

```bash
git clone https://github.com/code-and-secure/3-Tier-Web-App.git
cd 3-Tier-Web-App
```

**Option B — a local shell on the same machine as the project files**

Use PowerShell or Git Bash *on the same OS install* where the repo lives
(e.g. `cd D:\Zeeshan\3-Tier-Web-App` in Windows PowerShell), then:

```bash
az login
```

Complete sign-in (and MFA, if prompted) in the browser window that opens.

> Don't run `az` commands from an unrelated VM or WSL/Linux distro that
> doesn't actually have this folder mounted — see
> [Troubleshooting](#troubleshooting) below.

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
keeps it out of source control — this is worth practicing as a habit. See
[SECURITY.md](SECURITY.md) for password requirements and other secret
handling notes.

Deployment takes a few minutes (SQL Server/database provisioning is usually
the slowest step). When it finishes, grab the web app URL from the outputs:

```bash
az deployment sub show \
  --name bicep-practice-deploy \
  --query properties.outputs.webAppUrl.value -o tsv
```

Open that URL in a browser to confirm the default App Service page loads.

## Command reference

| Command | What it does |
|---|---|
| `az login` | Interactively authenticates the CLI to your Azure account via a browser sign-in. Not needed in Cloud Shell — you're already authenticated. |
| `az account show` / `az account list -o table` | Shows which subscription(s) the CLI currently sees for your account. Useful for confirming login actually worked and picking the right subscription if you have more than one. |
| `az account set --subscription "<id-or-name>"` | Switches the CLI's active subscription when you have multiple. |
| `az bicep install` | Installs/updates the Bicep CLI that `az` uses to compile `.bicep` files to ARM JSON under the hood. |
| `az deployment sub what-if` | Compiles the template and shows a **preview** of what would be created/changed/deleted at subscription scope, without actually deploying anything. Safe to run repeatedly. |
| `az deployment sub create` | Compiles and **actually deploys** the template at subscription scope — this is what creates the resource group and all resources inside it. |
| `az deployment sub show --name <deployment-name> --query ...` | Reads back outputs (like the web app URL) from a deployment that already ran, without redeploying. |
| `az group delete --name <rg-name> --yes --no-wait` | Deletes the entire resource group and everything in it. Used for cleanup — see below. |

Why `sub` (subscription scope) instead of the more common `group` scope:
`main.bicep` sets `targetScope = 'subscription'` so it can create the
resource group itself as part of the deployment, rather than requiring you
to create the resource group manually first.

## Troubleshooting

Issues actually hit while working through this project, and how they were
resolved:

**`Please enter one of the following: template file, template spec, template
url, or Bicep parameters file.`**
The `--location` flag got separated from the rest of the command by a shell
line-continuation issue (e.g. a stray blank pasted line breaking the `\`
continuation). Re-run the full command as a single block, or remove the `\`
continuations and put it on one line.

**`Could not find file '/home/zee/main.bicep'` (or similar path-not-found)**
The shell's current directory doesn't contain the repo. Run `pwd` and `ls`
first to confirm you're actually inside the cloned/copied project folder,
then `cd` into it before running `az` commands. This commonly happens when
the terminal you're typing in (e.g. a separate Linux VM) is a different
machine than the one the project files live on — Windows drives are **not**
automatically visible inside an unrelated VM or WSL distro unless explicitly
shared/mounted.

**`cd /mnt/...` shows only `cdrom` and `hgfs`, no Windows drives**
`hgfs` indicates a VMware Linux VM, not WSL — the Windows D: drive isn't
mounted by default. Either enable VMware Shared Folders for that VM, `git
clone` the repo directly inside the VM, or (simplest) just run the commands
from a Windows-native PowerShell/Git Bash terminal instead of the VM.

**`AADSTS50076: ... you must use multi-factor authentication` /
`No subscriptions found for <account>`**
`az login`'s device-code/basic flow failed to satisfy the tenant's MFA
requirement, or the account has no subscription under the tenant it
defaulted to. Easiest fix: use **Azure Cloud Shell**
(portal.azure.com > `>_` icon) instead — it's already authenticated as your
signed-in account and sidesteps local MFA/tenant issues entirely. If Cloud
Shell also reports no subscriptions, you likely need to create one first at
[azure.microsoft.com/free](https://azure.microsoft.com/free).

**SQL deployment fails on password complexity**
Azure SQL requires the admin password to be 8-128 characters and include
characters from at least 3 of: uppercase, lowercase, digits, special
characters, and it must not contain the admin login name. A password like
`3tierwebapp` will pass `what-if` (which doesn't fully validate password
rules) but fail at actual `create` time. Use something like
`Zt13rWebApp!2026` instead.

**`BCP334` warning about storage account naming during `what-if`**
Harmless — it's a static-analysis warning about the theoretical minimum
length of the generated storage account name, not an actual failure. Safe to
ignore for this template.

**`useFreeLimit` SQL deployment fails**
Azure only allows one free-tier SQL database per subscription. If you've
already used it elsewhere, this module will fail — check the Azure Portal's
SQL free offer page, or remove `useFreeLimit` from
[modules/sqlDatabase.bicep](modules/sqlDatabase.bicep) and accept normal
billing for that resource.

**Free-tier quota/region errors on App Service or SQL**
Availability varies by region. If `eastus` fails, try `westus2` or
`centralus` by changing the `location` parameter.

## Clean up

Free tier resources still count toward subscription quotas (e.g. the free
SQL database is one per subscription), so delete the resource group when
you're done experimenting:

```bash
az group delete --name rg-3tierwebapp-dev --yes --no-wait
```

(Resource group name follows `rg-<projectName>-<environment>` — adjust if
you changed `projectName` or `environment` in `main.parameters.json`.)

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

## Security

See [SECURITY.md](SECURITY.md) for secret-handling guidance, known scope
trade-offs in this template (e.g. Key Vault RBAC scope, public endpoints),
and how to report an issue.

## License

MIT — see [LICENSE](LICENSE).
