# 3-Tier-Web-App

## Purpose

This project exists to **practice Azure infrastructure-as-code (Bicep)** and
**basic full-stack development**, using a real (if small) app as the excuse.
It's a learning project, not a production system. Along the way it covers
Bicep concepts you'll actually use day to day: modules, parameters,
variables, outputs, secure params, dependencies via `outputs`, RBAC role
assignments, and subscription-scope deployment — plus a working example of
how a frontend, a backend, and a database talk to each other securely.

## What's actually going on here (plain English)

Think of this repo as building a tiny house, one room at a time, using code
instead of bricks:

1. **`main.bicep` is the blueprint.** Running it tells Azure "build me all of
   this" — a resource group (a folder to keep everything organized), a
   network, a place to store files, a vault for secrets, a database, and a
   web server. Azure reads the blueprint and creates the real resources.
2. **`app/` is the actual website** that runs *inside* the web server Azure
   created. It's a simple guestbook: a form where someone types their name,
   email, and a message, which gets saved into the database, and a list
   below it that shows everyone who's signed so far.
3. **The pieces are wired together so nothing insecure is exposed.** The
   database password is never written in plain text anywhere — it's locked
   in the vault, and the web server is given quiet, automatic permission to
   read it (a "Key Vault reference"), instead of the password being pasted
   into settings or code where anyone with access could see it.
4. **A separate service watches everything while it runs** (Log Analytics +
   Application Insights) — every time someone visits the site or submits the
   form, it quietly records what happened, so if something breaks you can
   look at the logs instead of guessing.

So in short: you write a description of the infrastructure you want → Azure
builds it → your app code runs on top of it → a monitoring service watches
it all.

## Important: this is *not* entirely free

Azure's "free tier" doesn't mean every service here costs nothing forever —
each service has its **own free allowance**, and once you go past that
allowance, it starts billing normally (against your subscription's credits
or payment method). Some resources below are free with essentially no
limit for a learning project (like the resource group or virtual network),
others are free only up to a certain amount of usage per day/month, and
going over that amount is where real charges can start:

| Resource | SKU / tier | Free tier note |
|---|---|---|
| Resource group | - | free |
| Virtual network + 2 subnets | - | free |
| App Service Plan + Web App | F1 (Free) | 60 CPU min/day free — extra usage isn't billed on F1, the app just gets throttled/paused instead |
| Storage account | Standard_LRS | ~5GB free for 12 months on a new subscription — billed per GB after that |
| Key Vault | Standard | first 10k operations/month free — billed per operation after that |
| SQL Server + Database | GP_S_Gen5_1 with `useFreeLimit` | 100,000 vCore-seconds & 32GB free/month (1 free database per subscription) — billed normally after that, or auto-paused depending on `freeLimitExhaustionBehavior` |
| Log Analytics workspace + App Insights | PerGB2018 | 5GB/day ingestion free — billed per GB after that |

**Practical takeaway:** for a small personal guestbook you're testing
casually, you're very unlikely to exceed any of these limits. But keep an
eye on your subscription's **Costs** page in the Azure Portal while
experimenting, and see [Clean up](#clean-up) below to delete everything
when you're done so nothing keeps running (and potentially billing) in the
background.

## What gets deployed

## Project structure

```
azure-bicep-practice/
├── main.bicep                  # orchestrator, subscription-scoped
├── main.parameters.json        # parameter values
├── modules/
│   ├── network.bicep           # VNet + app/data subnets
│   ├── logAnalytics.bicep      # Log Analytics + App Insights
│   ├── storageAccount.bicep    # storage account + blob container
│   ├── keyVault.bicep          # Key Vault (RBAC auth)
│   ├── keyVaultSecret.bicep    # generic "write one secret" module
│   ├── sqlDatabase.bicep       # SQL server + free-tier database
│   └── appService.bicep        # App Service plan (F1) + web app
└── app/                        # Node.js guestbook app deployed to the Web App
    ├── package.json
    ├── server.js                # Express server + API routes
    ├── db.js                    # SQL connection + queries (mssql package)
    └── public/                  # static frontend (index.html, styles.css, app.js)
```

## The app

`app/` is a minimal guestbook: a responsive form (name, email, message) that
writes rows into the `GuestbookEntries` table in the SQL Database, and a list
that reads them back. It runs on the App Service Web App the Bicep template
provisions, and demonstrates the 3-tier shape end to end:

- **Presentation** — static HTML/CSS/JS served from `app/public/`
- **Application** — Express routes in `app/server.js`
- **Data** — Azure SQL Database, connected via `app/db.js`

The SQL password never appears in app code or app settings in plaintext —
it's stored as a Key Vault secret (`sql-admin-password`, written by
`modules/keyVaultSecret.bicep`) and the Web App reads it through a
[Key Vault reference app
setting](https://learn.microsoft.com/azure/app-service/app-service-key-vault-references)
(`SQL_PASSWORD`), resolved automatically at runtime using the Web App's
managed identity. Server name, database name, and admin login aren't secret,
so they're passed as plain app settings (`SQL_SERVER`, `SQL_DATABASE`,
`SQL_USER`).

### Deploying the app code

The Bicep deployment only provisions the empty Web App — deploy the app code
separately with zip deploy:

```bash
cd app
npm install --omit=dev
zip -r ../app.zip . -x "node_modules/.cache/*"
cd ..

az webapp deploy \
  --resource-group rg-3tierwebapp-dev \
  --name <your-web-app-name> \
  --src-path app.zip \
  --type zip
```

Find `<your-web-app-name>` from the deployment output (`webAppUrl`) or:
```bash
az webapp list --resource-group rg-3tierwebapp-dev --query "[].name" -o tsv
```

Give it a minute after deploy, then reload the web app URL — the guestbook
page should replace the default placeholder page.

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
| `az group delete --name <rg-name> --yes --no-wait` | Deletes the entire resource group and everything in it, without waiting for the delete to finish. Used for cleanup — see below. |
| `az group exists --name <rg-name>` | Checks whether a resource group still exists — prints `true`/`false`. Use to confirm a `--no-wait` delete has actually finished before redeploying. |
| `az keyvault purge --name <vault-name> --location <original-location>` | Permanently removes a soft-deleted Key Vault so its name can be reused. Needed because `az group delete` only soft-deletes vaults, not hard-deletes them. |

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
Availability varies by region and by subscription — quota/capacity errors
here are Azure-side, not a template problem. If a region fails, try another
(e.g. `eastus` → `westus2` → `koreacentral`) by changing the `location`
parameter. `RegionDoesNotAllowProvisioning` for SQL and
`Current Limit (Total VMs): 0` for App Service are both regional
capacity/quota issues that clear up by switching regions.

**`SKU '' does not support Virtual Network Integration` on the App Service
deployment**
The **F1 (Free) App Service tier does not support VNet Integration** —
that requires Basic (B1) tier or above. This was a template bug: the web app
was wired into the VNet subnet even though the plan was F1. Fixed by
removing `virtualNetworkSubnetId` from
[modules/appService.bicep](modules/appService.bicep) — the VNet and its
subnets still get created by
[modules/network.bicep](modules/network.bicep) for learning purposes, the
web app just isn't integrated into it while on the free tier.

**Key Vault `VaultAlreadyExists` after deleting the resource group**
Key Vault has **soft-delete** protection by default — deleting the resource
group doesn't fully remove the vault, it goes into a recoverable state for
a retention period. If you redeploy and get this error, purge it first
(note: `--location` must be the region the vault was *originally* created
in, not your new target region):
```bash
az keyvault purge --name <vault-name> --location <original-location>
```

**Redeploying too soon after `az group delete --no-wait`**
`--no-wait` returns immediately and deletes in the background — if you
redeploy right away you can hit naming/location conflicts because the old
resources aren't gone yet. Check whether the group still exists:
```bash
az group exists --name rg-3tierwebapp-dev
```
`true` means it's still deleting. Poll until it flips to `false` before
redeploying:
```bash
until [ $(az group exists --name rg-3tierwebapp-dev) = "false" ]; do sleep 15; echo checking...; done; echo done
```

**`InvalidDeploymentLocation` — deployment 'X' already exists in location
'Y'**
At subscription scope, a deployment **name** is tied to the location it was
first used with. Reusing the same `--name` with a different `--location`
fails. Either delete the old deployment record (`az deployment sub delete
--name <name>`) or just use a new `--name` for each region you try (e.g.
`bicep-practice-deploy-koreacentral`).

## Clean up

Free tier resources still count toward subscription quotas (e.g. the free
SQL database is one per subscription), so delete the resource group when
you're done experimenting:

```bash
az group delete --name rg-3tierwebapp-dev --yes --no-wait
```

(Resource group name follows `rg-<projectName>-<environment>` — adjust if
you changed `projectName` or `environment` in `main.parameters.json`.)

### Full teardown (remove everything, including soft-deleted remnants)

`az group delete` removes every resource in the group, but **Key Vault has
soft-delete protection** — the vault itself survives in a recoverable state
for its retention period (`softDeleteRetentionInDays`, 7 days in this
template) even after the resource group is gone. If you want a completely
clean subscription with nothing left behind (e.g. before handing off the
subscription, or to immediately reuse the same `projectName`), wait for the
group delete to finish and then purge the vault:

```bash
# 1. Delete the resource group and wait for it to fully finish
az group delete --name rg-3tierwebapp-dev --yes
```

```bash
# 2. Purge the soft-deleted Key Vault (permanently removes it)
az keyvault purge --name <vault-name> --location <region-it-was-deployed-in>
```

Find `<vault-name>` (if you don't already know it) while the vault is still
soft-deleted:
```bash
az keyvault list-deleted --query "[].name" -o tsv
```

Note step 1 omits `--no-wait` here on purpose — the command blocks until
deletion is confirmed complete, so you don't need to poll `az group exists`
before running the purge.

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
