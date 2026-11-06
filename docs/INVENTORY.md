# Inventory of the legacy Apigee shell toolkit

This table maps every script found in the legacy toolkit copies to its
replacement in this repository. Files were deduplicated by name and content;
when copies differed, the newest version (2024 working tree, including
uncommitted edits) was used to describe behaviour. Variants such as
`(1)` copies, `.bkp`/`.sh` duplicates and the `dph2/`, `dph3/` and `test/`
duplicates are listed together on one row.

Names of a former client are redacted as `<client>` (for example
`get<client>KVMValue`). No credentials, client data, organization names or
hosts from the legacy sources were copied into this repository.

**Source copies**

| Key | Copy |
|-----|------|
| T | 2024 toolkit (working tree with uncommitted edits, plus `dev` and `master` branches) |
| Z | `astk.zip` archive found inside T (`apigeetools/bin/astk.zip`) |
| G | 2018 toolkit (`master` working tree and HEAD; its `origin/dev` equals the 2024 snapshot) |
| A | `astk` repository (2017 HEAD, files deleted in the working tree; `origin/development` 2016; `origin/dev` 2024) |
| O | `apigee-script-toolkit.old` (`master` holds only a README; `origin/dev` is the 2024 snapshot) |

**gcloud coverage** refers to the `gcloud apigee` command group, which only
offers: apis deploy/describe/list/undeploy; applications describe/list;
deployments describe/list; developers describe/list; environments list;
organizations list; products create/delete/describe/list/update.

**Summary**

| Metric | Count |
|--------|-------|
| Logical scripts / file groups (rows below) | 263 |
| Distinct files across all copies | 480 |
| Implemented in this toolkit | 119 |
| Covered by gcloud (fully or partly) | 38 (of which 4 are left to gcloud and not reimplemented) |
| Replaced by toolkit infrastructure (profiles, lib, tests, README) | 39 |
| Kept as a tool | 1 |
| Dropped | 100 (artifact: 9, client-specific: 12, edge-only-legacy: 37, out-of-scope: 38, superseded: 4) |

| Original name(s) | Source copies | What it does | Edge API used | X/hybrid equivalent | Covered by gcloud? | New command or dropped (reason) |
|---|---|---|---|---|---|---|
| `.gitignore`, `bin/.gitignore` | TGAO | Editor swap files, tmp/out files, awk scratch, .DS_Store, archives | — | n/a | n/a | dropped (artifacts) |
| `README.md` | TGAO | Old README / setup notes | — | n/a | n/a | rewritten as README.md |
| `.DT2` | TGAO | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `.tmp`, `bin/.tmp` | T | Editor swap files, tmp/out files, awk scratch, .DS_Store, archives | — | n/a | n/a | dropped (artifacts) |
| `.vimrc` | TGAO | Editor swap files, tmp/out files, awk scratch, .DS_Store, archives | — | n/a | n/a | dropped (artifacts) |
| `bin/.importAll.swp` | A | Editor swap files, tmp/out files, awk scratch, .DS_Store, archives | — | n/a | n/a | dropped (artifacts) |
| `bin/.updateAll.swp` | A | Editor swap files, tmp/out files, awk scratch, .DS_Store, archives | — | n/a | n/a | dropped (artifacts) |
| `bin/<client>.AppNames.txt` | A | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `bin/ProdEAST` | A | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `bin/TS-MyID.xml` | A | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `bin/addCredential`, `bin/dph2/addCredential` | TGAO | Developer app credential / key management | `/o/{org}/developers/${DEVELOPER}/apps/${APP_NAME_ESCAPED}/keys/create` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/addEnvironmentServer`, `bin/dph3/addEnvironmentServer` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | `/o/{org}/environments/{name}` | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/apigee.sh` | A | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/astk.zip` | T | Editor swap files, tmp/out files, awk scratch, .DS_Store, archives | — | n/a | n/a | dropped (artifacts) |
| `bin/attachProx2Product`, `bin/dph3/attachProx2Product` | TGAO | Create / update / delete / attach-proxy API products | `/o/{org}/apiproducts` | POST/PUT/DELETE .../apiproducts | yes (products create/update/delete) | covered by gcloud (`gcloud apigee products create\|update\|delete`); not reimplemented |
| `bin/auditKeys`, `bin/dph3/auditKeys` | TGAO | Developer app credential / key management | `/organizations/{organizationname}?expand=true` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/awk.inf`, `lib/awk.inf` | TZGAO | Editor swap files, tmp/out files, awk scratch, .DS_Store, archives | — | n/a | n/a | dropped (artifacts) |
| `bin/bldBody`, `bin/dph2/bldBody` | TGA | Build JSON bodies from name:value pairs | — | n/a | n/a | replaced by `lib/json.sh` (jq / python3) |
| `bin/buildTest` | A | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `bin/checkHealth` | TZGAO | Environment / API health checks | — | GET env + deployments | no | `apigee env health` (+ `setup/doctor.sh`) |
| `bin/checkTestOut` | A | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `bin/chk-del-api-rev`, `bin/dph3/chk-del-api-rev` | TGAO | Delete proxy revision(s) / ranges | — | DELETE .../apis/{api}/revisions/{rev} | no | `apigee proxy delete-revision` (ranges supported) |
| `bin/chk1rtr` | A | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `bin/chkClient` | A | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `bin/chkDeployments` | A | Revision(s) deployed per environment | `/o/<client>/deployments` | GET .../environments/{env}/apis/{api}/deployments; .../apis/{api}/deployments | yes (deployments list/describe) | `apigee proxy deployed [--all-envs]` |
| `bin/chkMetrics` | A | Analytics stats / reports | — | X: .../environments/{env}/stats, async queries | no | dropped (use the Apigee UI, apigeecli or BigQuery analytics export) |
| `bin/chkenv`, `bin/dph3/chkenv` | TGAO | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/cleanKVMKeys` | TZGAO | Flush a map (delete + recreate, or delete every key) | `/o/{org}/e/{env}/keyvaluemaps/${kvm_name}/entries/$k`; `/o/{org}/e/{env}/keyvaluemaps/${kvm_name}?expand=true` | DELETE map/entries + POST map | no | `apigee kvm export` + `apigee kvm delete MAP` + `apigee kvm create MAP` (no single verb) |
| `bin/cleanKeyValueMap` | TZGAO | Flush a map (delete + recreate, or delete every key) | `/o/{org_name}/environments/{env_name}/keyvaluemaps` | DELETE map/entries + POST map | no | `apigee kvm export` + `apigee kvm delete MAP` + `apigee kvm create MAP` (no single verb) |
| `bin/clearCache`, `bin/dph3/clearCache` | TGAO | Clear a cache | `/o/{org}/e/{env}/caches/{name}` | Edge: POST .../caches/{c}/entries?action=clear; X: none | no | `apigee cache clear` (Edge only) |
| `bin/clientsValidate` | A | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `bin/cmpApiSCM` | TZGAO | Diff two revisions, or a revision vs. a git/SCM checkout | — | GET bundle x2 + diff | no | `apigee proxy compare [A [B]] [--dir DIR]` |
| `bin/cmpApiVersions` | TZGAO | Diff two revisions, or a revision vs. a git/SCM checkout | — | GET bundle x2 + diff | no | `apigee proxy compare [A [B]] [--dir DIR]` |
| `bin/cmpSFVersions`, `bin/cmpSFVersions (1).sh`, `bin/cmpSFVersions.sh` | TZGAO | Diff two shared flow revisions | — | GET bundle x2 + diff | no | `apigee sharedflow compare` |
| `bin/compare`, `bin/dph2/compare` | TGAO | Diff two revisions, or a revision vs. a git/SCM checkout | `/o/{org}/apis/${APINAME}/revisions/latest?format=bundle` | GET bundle x2 + diff | no | `apigee proxy compare [A [B]] [--dir DIR]` |
| `bin/crOrgEnv`, `bin/dph2/crOrgEnv` | TGAO | Create / delete organizations or environments | — | X: provisioning via gcloud/Terraform; Edge: OPDK admin | no | dropped (provisioning; use Terraform / gcloud apigee organizations provision) |
| `bin/createApiProduct`, `bin/dph3/createApiProduct` | TGAO | Create / update / delete / attach-proxy API products | `/o/{org}/apiproducts` | POST/PUT/DELETE .../apiproducts | yes (products create/update/delete) | covered by gcloud (`gcloud apigee products create\|update\|delete`); not reimplemented |
| `bin/createApiProxyZip`, `bin/dph2/createApiProxyZip` | TGAO | Zip a local proxy and import it (optionally deploy) | — | POST .../apis?action=import&name={api} (multipart) | no | `apigee proxy import` (+ `apigee proxy deploy --latest`) |
| `bin/createApp`, `bin/dph2/createApp` | TGAO | Create / load / delete developer apps | `/o/{org}/developers/${DEVELOPER}/apps` | POST/DELETE .../developers/{dev}/apps | no | dropped (app provisioning is out of scope; use apigeecli `apps create/delete` or the portal) |
| `bin/createApps`, `bin/dph3/createApps` | TGAO | Create / load / delete developer apps | — | POST/DELETE .../developers/{dev}/apps | no | dropped (app provisioning is out of scope; use apigeecli `apps create/delete` or the portal) |
| `bin/createCache`, `bin/dph3/createCache` | TGAO | Create / delete / inspect caches | `/o/{org}/e/{env}/caches` | Edge only | no | dropped (Edge-only cache administration; X caches are implicit) |
| `bin/createCaches`, `bin/dph3/createCaches` | TGAO | Create / delete / inspect caches | — | Edge only | no | dropped (Edge-only cache administration; X caches are implicit) |
| `bin/createDeveloper`, `bin/dph2/createDeveloper` | TGAO | Create / delete developers | `/o/{org}/developers` | POST/DELETE .../developers | no | dropped (developer provisioning out of scope; use apigeecli `developers`) |
| `bin/createEnvironment`, `bin/dph3/createEnvironment` | TGAO | Create / delete organizations or environments | `/o/{org}/environments` | X: provisioning via gcloud/Terraform; Edge: OPDK admin | no | dropped (provisioning; use Terraform / gcloud apigee organizations provision) |
| `bin/createKeyValueMap` | TZGAO | Create a key value map | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/organizations/{org}/environments/{env}/keyvaluemaps` | POST .../keyvaluemaps | no | `apigee kvm create MAP` |
| `bin/createSslVirtualHost`, `bin/dph2/createSslVirtualHost` | TGAO | Create / update / delete virtual hosts | `/o/{org}/e/{name}` | Edge only | no | dropped (Edge-only write; X routing uses envgroups managed via gcloud/Terraform) |
| `bin/createTargetServer` | TZGAO | Create / configure target server(s) | `/o/{org}/e/{name}` | POST .../targetservers; PUT .../targetservers/{name} | no | `apigee target-server create\|update` |
| `bin/createUserRole`, `bin/dph3/createUserRole` | TGAO | User roles / RBAC administration | `/o/{org}/userroles` | Edge only; X uses Cloud IAM | no | dropped (Edge RBAC; X uses IAM) |
| `bin/createVirtualHost`, `bin/dph2/createVirtualHost` | TGAO | Create / update / delete virtual hosts | `/o/{org}/e/{env}/virtualhosts` | Edge only | no | dropped (Edge-only write; X routing uses envgroups managed via gcloud/Terraform) |
| `bin/crtgtsvr` | TZGAO | Create / configure target server(s) | `/o/{org}/e/{env}/targetservers` | POST .../targetservers; PUT .../targetservers/{name} | no | `apigee target-server create\|update` |
| `bin/cvtPEM2JWK.js` | TZGAO | PEM public key -> JWK thumbprint (node-jose) | — | n/a | n/a | kept as `tools/cvtPEM2JWK.js` |
| `bin/delKVMValue`, `bin/dph3/delKVMValue` | TGAO | Delete one KVM entry | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/o/{org}/keyvaluemaps/{name}` | DELETE .../keyvaluemaps/{map}/entries/{key} | no | `apigee kvm delete MAP KEY` |
| `bin/delTargetServer` | TZGAO | Delete a target server | `/o/{org}/e/{env}/targetservers/${ARGS[0]}` | DELETE .../targetservers/{name} | no | `apigee target-server delete` |
| `bin/delete-org.sh` | A | Delete everything in an org (teardown) | `/o/{o` | many DELETEs | no | dropped (destructive org teardown; out of scope) |
| `bin/deleteApi`, `bin/dph3/deleteApi` | TGAO | Delete an entire proxy | `/o/{org}/apis/{name}` | DELETE .../apis/{api} | no | dropped (whole-proxy delete is rare and destructive; use apigeecli `apis delete`) |
| `bin/deleteApiProduct`, `bin/dph3/deleteApiProduct` | TGAO | Create / update / delete / attach-proxy API products | `/o/{org}/apiproducts/{name}` | POST/PUT/DELETE .../apiproducts | yes (products create/update/delete) | covered by gcloud (`gcloud apigee products create\|update\|delete`); not reimplemented |
| `bin/deleteApiRevision` | TZGAO | Delete proxy revision(s) / ranges | `/o/{org}/apis/${theApi}/revisions/${theRevision}` | DELETE .../apis/{api}/revisions/{rev} | no | `apigee proxy delete-revision` (ranges supported) |
| `bin/deleteApisBulk`, `bin/dph3/deleteApisBulk` | TGAO | Bulk-delete old proxy revisions | — | DELETE .../apis/{api}/revisions/{rev} | no | `apigee proxy clean-revisions [--all] [--keep N]` |
| `bin/deleteApp`, `bin/dph3/deleteApp` | TGAO | Create / load / delete developer apps | `/o/{org_name}/developers/{developer_email}/apps/{app_name}/keys/{consumer_key}`; `/o/{org}/developers/${DEVELOPER}/apps/{name}` | POST/DELETE .../developers/{dev}/apps | no | dropped (app provisioning is out of scope; use apigeecli `apps create/delete` or the portal) |
| `bin/deleteAppsBulk` | A | Create / load / delete developer apps | — | POST/DELETE .../developers/{dev}/apps | no | dropped (app provisioning is out of scope; use apigeecli `apps create/delete` or the portal) |
| `bin/deleteCache`, `bin/dph3/deleteCache` | TGAO | Create / delete / inspect caches | `/o/{org}/e/{env}/caches/{name}` | Edge only | no | dropped (Edge-only cache administration; X caches are implicit) |
| `bin/deleteCredential`, `bin/dph3/deleteCredential` | TGAO | Developer app credential / key management | `/o/{org}/developers/${DEVELOPER}/apps/{name}` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/deleteDeveloper`, `bin/dph3/deleteDeveloper` | TGAO | Create / delete developers | `/o/{org}/developers` | POST/DELETE .../developers | no | dropped (developer provisioning out of scope; use apigeecli `developers`) |
| `bin/deleteEnvironment`, `bin/dph3/deleteEnvironment` | TGAO | Create / delete organizations or environments | `/o/{org}/e/{name}` | X: provisioning via gcloud/Terraform; Edge: OPDK admin | no | dropped (provisioning; use Terraform / gcloud apigee organizations provision) |
| `bin/deleteEnvironmentServer`, `bin/dph3/deleteEnvironmentServer` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | `/o/{org}/environments/{name}` | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/deleteKeyValueMap` | TZGAO | Delete a key value map | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/o/{org}/environments/{env}/keyvaluemaps/$keyvaluemap_name` | DELETE .../keyvaluemaps/{map} | no | `apigee kvm delete MAP` |
| `bin/deleteKeys`, `bin/dph3/deleteKeys` | TGAO | Developer app credential / key management | `/o/{org_name}/developers/{developer_email}/apps/{app_name}/keys/{consumer_key}`; `/o/{org}/developers/${DEVELOPER}/apps/{name}` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/deleteSHFlowRevision` | TZ | Delete shared flow revision(s) / ranges | `/o/{org}/sharedflows/${theShF}/revisions/${theRevision}` | DELETE .../sharedflows/{sf}/revisions/{rev} | no | `apigee sharedflow delete-revision` / `clean-revisions` |
| `bin/deleteUserRole`, `bin/dph3/deleteUserRole` | TGAO | User roles / RBAC administration | `/o/{org}/userroles` | Edge only; X uses Cloud IAM | no | dropped (Edge RBAC; X uses IAM) |
| `bin/deleteVirtualHost`, `bin/dph2/deleteVirtualHost` | TGAO | Create / update / delete virtual hosts | `/o/{org}/e/`; `/o/{org}/e/{name}` | Edge only | no | dropped (Edge-only write; X routing uses envgroups managed via gcloud/Terraform) |
| `bin/deploy` | TZGAO | Deploy a proxy revision (incl. latest / override) | `/o/{org}/apis/${APINAME}/deployments?action=deploy&env={env}&revision=${VERSION}`; `/o/{org}/e/{env}/apis/${APINAME}/revisions/${VERSION}/deployments?override=true` | POST .../environments/{env}/apis/{api}/revisions/{rev}/deployments?override=true | yes (apis deploy) | `apigee proxy deploy REV\|--latest` |
| `bin/deployApi` | TZGAO | Deploy a proxy revision (incl. latest / override) | `/o/{org}/e/{env}/apis/${APINAME}/revisions/${REVISION}/deployments` | POST .../environments/{env}/apis/{api}/revisions/{rev}/deployments?override=true | yes (apis deploy) | `apigee proxy deploy REV\|--latest` |
| `bin/deployLatest` | TZGAO | Deploy a proxy revision (incl. latest / override) | — | POST .../environments/{env}/apis/{api}/revisions/{rev}/deployments?override=true | yes (apis deploy) | `apigee proxy deploy REV\|--latest` |
| `bin/deployLatestSF` | T | Deploy a shared flow revision (incl. latest) | — | POST .../environments/{env}/sharedflows/{sf}/revisions/{rev}/deployments | no | `apigee sharedflow deploy REV\|--latest` |
| `bin/deployOverride`, `bin/dph3/deployOverride` | TGAO | Deploy a proxy revision (incl. latest / override) | `/o/{org}/apis/${APINAME}/deployments?action=deploy&env={env}&revision=${VERSION}&override=` | POST .../environments/{env}/apis/{api}/revisions/{rev}/deployments?override=true | yes (apis deploy) | `apigee proxy deploy REV\|--latest` |
| `bin/deploySF` | T | Deploy a shared flow revision (incl. latest) | `/o/{org}/e/{env}/sharedflows/${SFNAME}/revisions/${REVISION}/deployments` | POST .../environments/{env}/sharedflows/{sf}/revisions/{rev}/deployments | no | `apigee sharedflow deploy REV\|--latest` |
| `bin/deploySHF` | TZ | Deploy a shared flow revision (incl. latest) | `/o/{org}/e/{env}/sharedflows/${SHFNAME}/revisions/${REVISION}/deployments` | POST .../environments/{env}/sharedflows/{sf}/revisions/{rev}/deployments | no | `apigee sharedflow deploy REV\|--latest` |
| `bin/dlAllApis`, `bin/dph2/dlAllApis` | TGAO | Download all proxies / deployed proxies of an env | — | same, per proxy | no | `apigee env export DIR` (deployed bundles) / `apigee proxy download` in a loop |
| `bin/dlApi` | TZGAO | Download a proxy bundle zip | `/o/{org}/apis/${APINAME}/revisions/${REV}?format=bundle` | GET .../apis/{api}/revisions/{rev}?format=bundle | no | `apigee proxy download` |
| `bin/dlApiEnv`, `bin/dlApiEnv (1).bkp`, `bin/dlApiEnv.bkp` | TZGAO | Move an environment: export (and re-upload) TS, vhosts, KVMs, shared flows, proxies | — | composition of the above | no | `apigee env export DIR`; upload half = `kvm import` + `target-server create` + `proxy\|sharedflow import/deploy` |
| `bin/dlKVMs` | TZGAO | Bulk export maps / keys / values to files | — | list + entries (+ helper proxy for encrypted Edge values) | no | `apigee kvm export [--format json\|lines] [--reader-url]` |
| `bin/dlSFlow` | TZGAO | Download a shared flow bundle | `/o/{org}/sharedflows/${SFNAME}/revisions/${REV}?format=bundle` | GET .../sharedflows/{sf}/revisions/{rev}?format=bundle | no | `apigee sharedflow download` |
| `bin/dph2/addUserRole` | TGAO | User roles / RBAC administration | `/o/{org}/userroles/$roleName/users?id=$USER` | Edge only; X uses Cloud IAM | no | dropped (Edge RBAC; X uses IAM) |
| `bin/dph2/createAppfromFile` | TGAO | Create / load / delete developer apps | `/o/{org}/developers/${DEVELOPER}/apps` | POST/DELETE .../developers/{dev}/apps | no | dropped (app provisioning is out of scope; use apigeecli `apps create/delete` or the portal) |
| `bin/dph2/createManySSLVHosts` | TGAO | Create / update / delete virtual hosts | — | Edge only | no | dropped (Edge-only write; X routing uses envgroups managed via gcloud/Terraform) |
| `bin/dph2/createManyVHosts` | TGAO | Create / update / delete virtual hosts | — | Edge only | no | dropped (Edge-only write; X routing uses envgroups managed via gcloud/Terraform) |
| `bin/dph2/createUser` | TGAO | User roles / RBAC administration | — | Edge only; X uses Cloud IAM | no | dropped (Edge RBAC; X uses IAM) |
| `bin/dph2/getAnals` | TGAO | Analytics stats / reports | `/o/{org}/e/{env}/analytics${STATSTR}` | X: .../environments/{env}/stats, async queries | no | dropped (use the Apigee UI, apigeecli or BigQuery analytics export) |
| `bin/dph2/getApigeeJson`, `bin/getApigeeJson` | TGAO | Raw GET of any management resource | — | any | n/a | dropped (use `curl -H "$(apigee token --header)" ...`) |
| `bin/dph2/getApigeeXml`, `bin/getApigeeXml` | TGAO | Raw GET of any management resource | — | any | n/a | dropped (use `curl -H "$(apigee token --header)" ...`) |
| `bin/dph2/getCache`, `bin/getCache` | TZGAO | Create / delete / inspect caches | `/o/{org}/e/{env}/caches/${CACHE}`; `/o/{org}/e/{env}/caches/{name}` | Edge only | no | dropped (Edge-only cache administration; X caches are implicit) |
| `bin/dph2/getCacheEntries`, `bin/getCacheEntries` | TGAO | Create / delete / inspect caches | `/o/{org}/e/{env}/caches/`; `/o/{org}/e/{env}/caches/{name}` | Edge only | no | dropped (Edge-only cache administration; X caches are implicit) |
| `bin/dph2/getDeveloper`, `bin/getDeveloper` | TGAO | Get a developer | `/o/{org}/developers/${DEVID}` | GET .../developers/{email} | yes (developers describe) | `apigee developer get` |
| `bin/dph2/getReport` | TGAO | Analytics stats / reports | `/organizations/{org}/environments/{env}/stats/\`; `/organizations/{org}/reports${RPTID}` | X: .../environments/{env}/stats, async queries | no | dropped (use the Apigee UI, apigeecli or BigQuery analytics export) |
| `bin/dph2/getReport.sh` | TGAO | Analytics stats / reports | `/o/{org}/e/{env}/reports/${RPTID}` | X: .../environments/{env}/stats, async queries | no | dropped (use the Apigee UI, apigeecli or BigQuery analytics export) |
| `bin/dph2/getRptTraffic` | TGAO | Analytics stats / reports | `/organizations/{org}/environments/{env}/stats/\`; `/organizations/{org}/reports${RPTID}` | X: .../environments/{env}/stats, async queries | no | dropped (use the Apigee UI, apigeecli or BigQuery analytics export) |
| `bin/dph2/getRptTrafficMonth` | TGAO | Analytics stats / reports | `/organizations/{org}/environments/{env}/stats/\`; `/organizations/{org}/reports${RPTID}` | X: .../environments/{env}/stats, async queries | no | dropped (use the Apigee UI, apigeecli or BigQuery analytics export) |
| `bin/dph2/getStats` | TGAO | Analytics stats / reports | `/o/{org}/e/{env}/stats${STATSTR}` | X: .../environments/{env}/stats, async queries | no | dropped (use the Apigee UI, apigeecli or BigQuery analytics export) |
| `bin/dph2/importAll`, `bin/importAll` | TGAO | Zip a local proxy and import it (optionally deploy) | — | POST .../apis?action=import&name={api} (multipart) | no | `apigee proxy import` (+ `apigee proxy deploy --latest`) |
| `bin/dph2/listStaleApis`, `bin/listStaleApis` | TGAO | Proxies whose deployed revision is older than the latest | — | deployments + revisions | no | `apigee proxy deployed` + `apigee proxy latest` |
| `bin/dph2/loadApp`, `bin/loadApp` | TGAO | Create / load / delete developer apps | `/o/{org}/developers/${DEVELOPER}/apps` | POST/DELETE .../developers/{dev}/apps | no | dropped (app provisioning is out of scope; use apigeecli `apps create/delete` or the portal) |
| `bin/dph2/mvApiEnv` | TGAO | Move an environment: export (and re-upload) TS, vhosts, KVMs, shared flows, proxies | — | composition of the above | no | `apigee env export DIR`; upload half = `kvm import` + `target-server create` + `proxy\|sharedflow import/deploy` |
| `bin/dph2/postApp` | TGAO | Create / load / delete developer apps | `/o/{org}/developers/${DEVELOPER}/apps/${APP_NAME}` | POST/DELETE .../developers/{dev}/apps | no | dropped (app provisioning is out of scope; use apigeecli `apps create/delete` or the portal) |
| `bin/dph2/setCredentialApiProduct`, `bin/setCredentialApiProduct` | TGAO | Developer app credential / key management | `/o/{org}/developers/$DEVELOPER/apps/{name}` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/dph2/updateCredential`, `bin/updateCredential`, `bin/updateCredntial` | TGAO | Developer app credential / key management | `/o/{org}/developers/${DEVELOPER}/apps/${APP_NAME_ESCAPED}/keys/${CONSUMER_KEY}` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/dph2/updateSCM`, `bin/updateSCM` | TGAO | git wrapper for proxy source | — | n/a | n/a | dropped (use git directly; `apigee proxy compare --dir`) |
| `bin/dph2/updateVirtualHost` | TGAO | Create / update / delete virtual hosts | — | Edge only | no | dropped (Edge-only write; X routing uses envgroups managed via gcloud/Terraform) |
| `bin/dph2/uploadKeyCert` | TGAO | Upload a key/cert to a keystore | `/o/{org}/e/{env}/keystores`; `/o/{org}/e/{env}/keystores/${keystore_name}/aliases?alias=${alias_name}&format=keycertfile` | POST .../keystores/{ks}/aliases?format=keycertfile | no | dropped (write path for TLS material; use apigeecli `keystores`/`aliases` or Terraform) |
| `bin/dph3/chkNodes` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | `/o/{org}/apis`; `/o/{org}/apis/$API` | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/dph3/createDeveloperfromFile.sh` | TGAO | Create / delete developers | `/o/{org}/developers` | POST/DELETE .../developers | no | dropped (developer provisioning out of scope; use apigeecli `developers`) |
| `bin/dph3/delOrg` | TGAO | Delete everything in an org (teardown) | `/o/{o` | many DELETEs | no | dropped (destructive org teardown; out of scope) |
| `bin/dph3/deleteUser` | TGAO | User roles / RBAC administration | — | Edge only; X uses Cloud IAM | no | dropped (Edge RBAC; X uses IAM) |
| `bin/dph3/examAPIs`, `bin/examAPIs` | TGAO | Download all proxies / deployed proxies of an env | — | same, per proxy | no | `apigee env export DIR` (deployed bundles) / `apigee proxy download` in a loop |
| `bin/dph3/findApiProducts`, `bin/findApiProducts`, `test/findApiProducts` | TGAO | List API products | — | GET /organizations/{org}/apiproducts | yes (products list) | `apigee product list` |
| `bin/dph3/findBroken.tmplt`, `bin/findBroken.tmplt`, `test/findBroken.tmplt` | TGAO | Find orphaned products / proxies / apps / developers | — | list + get across resources | no | dropped for now (candidate skill: consistency audit) |
| `bin/dph3/findBrokenApiProxies`, `bin/findBrokenApiProxies`, `test/findBrokenApiProxies` | TGAO | Find orphaned products / proxies / apps / developers | — | list + get across resources | no | dropped for now (candidate skill: consistency audit) |
| `bin/dph3/findBrokenApps`, `bin/findBrokenApps`, `test/findBrokenApps` | TGAO | Find orphaned products / proxies / apps / developers | — | list + get across resources | no | dropped for now (candidate skill: consistency audit) |
| `bin/dph3/findBrokenProducts`, `bin/findBrokenProducts`, `test/findBrokenProducts` | TGAO | Find orphaned products / proxies / apps / developers | — | list + get across resources | no | dropped for now (candidate skill: consistency audit) |
| `bin/dph3/getApiProduct`, `bin/getApiProduct` | TGAO | Get an API product (incl. its proxies) | `/o/{org}/apiproducts/{name}` | GET .../apiproducts/{name} | yes (products describe) | `apigee product get` |
| `bin/dph3/getCredential`, `bin/getCredential` | TGAO | Developer app credential / key management | `/o/{org}/developers/${DEVELOPER}/apps/{name}` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/dph3/getCredentials`, `bin/getCredentials` | TGAO | Developer app credential / key management | `/o/{org}/developers/${DEVELOPER}/apps/{name}` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/dph3/getDeployedStatus`, `bin/getDeployedStatus` | TGAO | Revision(s) deployed per environment | `/o/{org}/apis/$API_NAME/deployments`; `/o/{org}/e/{env}/apis/{name}` | GET .../environments/{env}/apis/{api}/deployments; .../apis/{api}/deployments | yes (deployments list/describe) | `apigee proxy deployed [--all-envs]` |
| `bin/dph3/getDeployments`, `bin/getDeployments` | TGAO | Revision(s) deployed per environment | `/o/{org}/deployments` | GET .../environments/{env}/apis/{api}/deployments; .../apis/{api}/deployments | yes (deployments list/describe) | `apigee proxy deployed [--all-envs]` |
| `bin/dph3/getEnvSrvrUuid`, `bin/getEnvSrvrUuid` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | `/o/{org}/e/{name}` | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/dph3/getEnvironmentServers`, `bin/getEnvironmentServers` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | `/o/{org}/e/{name}` | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/dph3/getEnvironments`, `bin/getEnvironments` | TGAO | List environments | `/o/{org}/environments` | GET /organizations/{org}/environments | yes (environments list) | `apigee env list` |
| `bin/dph3/getHost`, `bin/getHost` | TGAO | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/dph3/getHostUrl`, `bin/getHostUrl` | TGAO | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/dph3/getKVMVDev`, `bin/getKVMVDev` | TGAO | Get one KVM value | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/o/{org}/environments/{env}/keyvaluemaps/{name}` | GET .../keyvaluemaps/{map}/entries/{key} | no | `apigee kvm get MAP KEY [--reader-url]` |
| `bin/dph3/getKVMValComp`, `bin/getKVMValComp` | TGAO | Get a company-scoped KVM value (Edge monetization) | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/o/{org}/companies/${COMPANYNAME}/keyvaluemaps/{name}` | none (companies do not exist on X) | no | dropped (Edge company scope; no X equivalent). Env/org/proxy scopes via `apigee kvm get` |
| `bin/dph3/getKey`, `bin/getKey` | TGAO | Developer app credential / key management | `/o/{org_name}/developers/{developer_email}/apps/{app_name}/keys/{consumer_key}` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/dph3/getKeys`, `bin/getKeys` | TGAO | Developer app credential / key management | `/o/{org_name}/developers/{developer_email}/apps/{app_name}/keys/{consumer_key}` | .../developers/{dev}/apps/{app}/keys[/{key}] | no | dropped (credential lifecycle out of scope; use apigeecli `apps keys`) |
| `bin/dph3/getOrganization`, `bin/getOrganization` | TGAO | Get the organization | `/o/{org}` | GET /organizations/{org} | partial (organizations list) | `apigee org get` |
| `bin/dph3/getProxFmProd`, `bin/getProxFmProd` | TGAO | Get an API product (incl. its proxies) | — | GET .../apiproducts/{name} | yes (products describe) | `apigee product get` |
| `bin/dph3/getResources`, `bin/getResources` | TGAO | Environment / org resource files | `/organizations/{org}/apis/${API_NAME}/revisions/${REVNUM}/resources`; `/organizations/{org}/environments/{env}/resourcefiles` | X: proxy-level resources only | no | dropped (Edge env resource files; bundle resources travel with proxies) |
| `bin/dph3/getServers`, `bin/getServers` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | — | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/dph3/getSet`, `bin/getSet` | TGAO | Print the current session variables | — | n/a | n/a | replaced by `apigee profile show` / `setup/doctor.sh` |
| `bin/dph3/getSrvrFmUuid`, `bin/getSrvrFmUuid` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | — | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/dph3/getSrvrIPaddr`, `bin/getSrvrIPaddr` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | — | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/dph3/getSrvrIPs`, `bin/getSrvrIPs` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | `/o/{org}/e/{name}`; `/o/{org}/servers` | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/dph3/getSrvrNames`, `bin/getSrvrNames` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | — | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/dph3/getUserRoles`, `bin/getUserRoles` | TGAO | User roles / RBAC administration | `/o/{org}/userroles` | Edge only; X uses Cloud IAM | no | dropped (Edge RBAC; X uses IAM) |
| `bin/dph3/listAppNames`, `bin/listAppNames` | TGAO | List developer apps / app names | `/o/{org}/developers/${DEVELOPER}/apps` | GET /organizations/{org}/apps[?expand=true] | yes (applications list) | `apigee app list [--expand]` |
| `bin/dph3/listDevelopers`, `bin/listDevelopers` | TGAO | List developers | `/o/{org}/developers` | GET /organizations/{org}/developers | yes (developers list) | `apigee developer list` |
| `bin/dph3/listRBACResources`, `bin/listRBACResources` | TGAO | User roles / RBAC administration | `/o/{org}/resources` | Edge only; X uses Cloud IAM | no | dropped (Edge RBAC; X uses IAM) |
| `bin/dph3/listUserRoles`, `bin/listUserRoles` | TGAO | User roles / RBAC administration | `/o/{org}/userroles` | Edge only; X uses Cloud IAM | no | dropped (Edge RBAC; X uses IAM) |
| `bin/dph3/listUsers`, `bin/listUsers` | TGAO | List org users | `/o/{org}/users` | Edge only; X uses Cloud IAM | no | `apigee user list` (Edge only) |
| `bin/dph3/loadBaasCollection`, `bin/loadBaasCollection` | TGAO | Load Apigee BaaS collections | — | none (BaaS retired) | no | dropped (Apigee BaaS is retired) |
| `bin/dph3/loadResource`, `bin/loadResource` | TGAO | Environment / org resource files | `/o/{org}/e/{env}/resourcefiles?name=${FILE_NAME}&type=jsc`; `/organizations/myorg/environments/myenv/resourcefiles?name=<filename>.js&type=jsc` | X: proxy-level resources only | no | dropped (Edge env resource files; bundle resources travel with proxies) |
| `bin/dph3/pushAllApis`, `bin/pushAllApis` | TGAO | Zip a local proxy and import it (optionally deploy) | — | POST .../apis?action=import&name={api} (multipart) | no | `apigee proxy import` (+ `apigee proxy deploy --latest`) |
| `bin/dph3/putKVMValue`, `bin/putKVMValue` | TGAO | Create/update one KVM entry | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/o/{org}/keyvaluemaps/{name}` | POST .../entries, then X: PUT / Edge: POST .../entries/{key} | no | `apigee kvm put MAP KEY (VALUE\|--value-file\|--value-stdin)` |
| `bin/dph3/putVHost` | TGAO | Create / update / delete virtual hosts | `/o/{org}/e/{env}/virtualhosts` | Edge only | no | dropped (Edge-only write; X routing uses envgroups managed via gcloud/Terraform) |
| `bin/dph3/updateApiProduct`, `bin/updateApiProduct` | TGAO | Create / update / delete / attach-proxy API products | `/o/{org}/apiproducts/${apiProductName}` | POST/PUT/DELETE .../apiproducts | yes (products create/update/delete) | covered by gcloud (`gcloud apigee products create\|update\|delete`); not reimplemented |
| `bin/dph3/zkDereg`, `bin/zkDereg` | TGAO | Edge for Private Cloud server / zookeeper / router / node internals | `/o/<org>/e/<env>/servers`; `/o/{org}/e/{env}/servers` | none | no | dropped (OPDK infrastructure; not applicable to X or Edge SaaS) |
| `bin/eula-chk` | A | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `bin/eula-telnet` | A | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `bin/get<client>KVMKeys` | TZ | Bulk export maps / keys / values to files | `/o/{org_name}/environments/{env_name}/keyvaluemaps` | list + entries (+ helper proxy for encrypted Edge values) | no | `apigee kvm export [--format json\|lines] [--reader-url]` |
| `bin/get<client>KVMNames` | TZ | Bulk export maps / keys / values to files | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/organizations/{org}/environments/{env}IRON/keyvaluemaps/$KVMN` | list + entries (+ helper proxy for encrypted Edge values) | no | `apigee kvm export [--format json\|lines] [--reader-url]` |
| `bin/get<client>KVMValue` | TZ | Get one KVM value | `/o/{org_name}/environments/{env_name}/keyvaluemaps` | GET .../keyvaluemaps/{map}/entries/{key} | no | `apigee kvm get MAP KEY [--reader-url]` |
| `bin/get<client>KVMaps` | TZ | List key value maps | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/organizations/{org}/environments/{env}IRON/keyvaluemaps` | GET .../environments/{env}/keyvaluemaps (also org / proxy scope) | no | `apigee kvm list [--scope ...]` |
| `bin/get<client>kvmsall` | TZ | Bulk export maps / keys / values to files | `/o/{org_name}/environments/{env_name}/keyvaluemaps` | list + entries (+ helper proxy for encrypted Edge values) | no | `apigee kvm export [--format json\|lines] [--reader-url]` |
| `bin/get<client>token` | TZ | Fetch an access token (gcloud or Edge OAuth) | — | gcloud auth print-access-token / Edge token endpoint | yes (gcloud auth print-access-token for X) | `apigee token` (Edge OAuth/basic creds from env or Keychain) |
| `bin/getApi` | TZGAO | List / describe proxy revisions | `/o/{org}/apis/${theApi}/revisions/${theRevision}` | GET .../apis/{api}/revisions | partial (apis describe) | `apigee proxy revisions` |
| `bin/getApiProducts` | TZGAO | List API products | `/o/{org}/apiproducts` | GET /organizations/{org}/apiproducts | yes (products list) | `apigee product list` |
| `bin/getApiRevisionDeployed` | TZGAO | Revision(s) deployed per environment | `/o/{org}/e/{env}/apis/${APINAME}/deployments` | GET .../environments/{env}/apis/{api}/deployments; .../apis/{api}/deployments | yes (deployments list/describe) | `apigee proxy deployed [--all-envs]` |
| `bin/getApiRevisionLatest` | TZGAO | Newest proxy revision number | — | GET .../apis/{api}/revisions (max) | partial (apis describe) | `apigee proxy latest` |
| `bin/getApiRevisions` | TZGAO | List / describe proxy revisions | `/o/{org}/apis/${APINAME}/revisions` | GET .../apis/{api}/revisions | partial (apis describe) | `apigee proxy revisions` |
| `bin/getApiVersionDeployed` | TZGAO | Revision(s) deployed per environment | `/o/{org}/e/{env}/apis/`; `/o/{org}/e/{env}/apis/{name}` | GET .../environments/{env}/apis/{api}/deployments; .../apis/{api}/deployments | yes (deployments list/describe) | `apigee proxy deployed [--all-envs]` |
| `bin/getApiVersionLatest` | GA | Newest proxy revision number | — | GET .../apis/{api}/revisions (max) | partial (apis describe) | `apigee proxy latest` |
| `bin/getApiVersions` | GA | List / describe proxy revisions | `/o/{org}/apis/${APINAME}` | GET .../apis/{api}/revisions | partial (apis describe) | `apigee proxy revisions` |
| `bin/getApis` | TZGAO | List API proxies | `/organizations/{org}/apis` | GET /organizations/{org}/apis | yes (apis list) | `apigee proxy list` |
| `bin/getApp` | TZGAO | Get a developer app | `/o/{org}/developers/${DEVELOPER}/apps/$APP_NAME` | GET .../apps/{id} or .../developers/{dev}/apps/{app} | yes (applications describe) | `apigee app get` |
| `bin/getAppNames` | TZGAO | List developer apps / app names | `/o/{org}/developers/${DEVELOPER}/apps` | GET /organizations/{org}/apps[?expand=true] | yes (applications list) | `apigee app list [--expand]` |
| `bin/getApps` | TZGAO | List developer apps / app names | `/o/{org}/apps` | GET /organizations/{org}/apps[?expand=true] | yes (applications list) | `apigee app list [--expand]` |
| `bin/getCaches` | TZGAO | List caches | `/o/{org}/e/{env}/caches` | Edge only (X has no cache list API) | no | `apigee cache list` (Edge only) |
| `bin/getDevelopers` | TZGAO | List developers | `/o/{org}/developers${QUERY}` | GET /organizations/{org}/developers | yes (developers list) | `apigee developer list` |
| `bin/getKVM` | TZGAO | Get a whole key value map | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/o/{org}/environments/{env}/keyvaluemaps/$keyvaluemap_name` | X: GET .../keyvaluemaps/{map}/entries (paged); Edge: GET .../keyvaluemaps/{map} | no | `apigee kvm get MAP` |
| `bin/getKVMValue` | TZGAO | Get one KVM value | `/o/{org_name}/e/{env_name}/keyvaluemaps`; `/o/{org}/e/{env}/keyvaluemaps/$keyvaluemap_name` | GET .../keyvaluemaps/{map}/entries/{key} | no | `apigee kvm get MAP KEY [--reader-url]` |
| `bin/getKVMValues` | TZGAO | Get a whole key value map | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/o/{org}/e/{env}/keyvaluemaps/${keyvaluemap_name}` | X: GET .../keyvaluemaps/{map}/entries (paged); Edge: GET .../keyvaluemaps/{map} | no | `apigee kvm get MAP` |
| `bin/getKVMs` | TZGAO | List key value maps | `/o/{org}/e/{env}/keyvaluemaps` | GET .../environments/{env}/keyvaluemaps (also org / proxy scope) | no | `apigee kvm list [--scope ...]` |
| `bin/getKeyValueMap` | GA | Get a whole key value map | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/o/{org}/environments/{env}/keyvaluemaps/$keyvaluemap_name` | X: GET .../keyvaluemaps/{map}/entries (paged); Edge: GET .../keyvaluemaps/{map} | no | `apigee kvm get MAP` |
| `bin/getKeyValueMaps` | GA | List key value maps | `/o/{org}/e/{env}/keyvaluemaps` | GET .../environments/{env}/keyvaluemaps (also org / proxy scope) | no | `apigee kvm list [--scope ...]` |
| `bin/getKeystore` | TZGAO | Get a keystore / truststore | `/o/{org}/e/{env}/keystores/${KEYSTORE_NAME}` | GET .../keystores/{name}[/aliases/{alias}] | no | `apigee keystore get` / `apigee truststore get` |
| `bin/getKeystores` | TZGAO | List keystores / truststores | `/o/{org}/e/{env}/keystores` | GET .../environments/{env}/keystores | no | `apigee keystore list` / `apigee truststore list` |
| `bin/getResourceFiles` | A | Environment / org resource files | `/organizations/{org_name}/apis/{api_name}/revisions/{revision_number}/resources`; `/organizations/{org_name}/environments/{environment_name}/resourcefiles` | X: proxy-level resources only | no | dropped (Edge env resource files; bundle resources travel with proxies) |
| `bin/getSF` | T | List shared flow revisions | `/o/{org}/sharedflows/${theSF}/revisions/${theRevision}` | GET .../sharedflows/{sf}/revisions | no | `apigee sharedflow revisions` |
| `bin/getSFRevisionDeployed` | TZGAO | Shared flow revision deployed in an env | `/o/{org}/e/{env}/sharedflows/${SFName}/deployments` | GET .../environments/{env}/sharedflows/{sf}/deployments | no | `apigee sharedflow deployed` |
| `bin/getSFRevisionLatest` | TZGAO | Newest shared flow revision | — | GET .../sharedflows/{sf}/revisions (max) | no | `apigee sharedflow latest` |
| `bin/getSFlowRevisions` | TZGAO | List shared flow revisions | `/o/{ORGANIZATION}/sharedflows/{sharedflow_name}/deployments`; `/o/{org}/sharedflows/${SFName}` | GET .../sharedflows/{sf}/revisions | no | `apigee sharedflow revisions` |
| `bin/getSFs` | TZGAO | List shared flows | `/o/{org}/sharedflows` | GET /organizations/{org}/sharedflows | no (gcloud apigee has no sharedflows group) | `apigee sharedflow list` |
| `bin/getTargetServer` | TZGAO | Get a target server | `/o/{org}/e/{env}/targetservers/${TS_NAME}` | GET .../targetservers/{name} | no | `apigee target-server get` |
| `bin/getTargetServers` | TZGAO | List target servers | `/o/{org}/e/{env}/targetservers` | GET .../environments/{env}/targetservers | no | `apigee target-server list` |
| `bin/getTrustStore` | TZGAO | Get a keystore / truststore | `/o/{org}/e/{env}/keystores/${ARGS[0]}` | GET .../keystores/{name}[/aliases/{alias}] | no | `apigee keystore get` / `apigee truststore get` |
| `bin/getTrustStores` | TZGAO | List keystores / truststores | `/o/{org}/e/{env}/keystores` | GET .../environments/{env}/keystores | no | `apigee keystore list` / `apigee truststore list` |
| `bin/getUsers` | TZGAO | List org users | `/o/{org}/users` | Edge only; X uses Cloud IAM | no | `apigee user list` (Edge only) |
| `bin/getVirtualHost` | TZGAO | Get a virtual host | `/o/{org}/e/{env}/virtualhosts/${VH_NAME}` | Edge only; X: GET /organizations/{org}/envgroups/{name} | no | `apigee virtualhost get` (Edge) / `apigee envgroup get` (X) |
| `bin/getVirtualHosts` | TZGAO | List virtual hosts | `/o/{org}/e/{env}/virtualhosts` | Edge only; X uses environment groups | no | `apigee virtualhost list` (Edge) / `apigee envgroup list` (X) |
| `bin/getenv` | TZGAO | Print the current session variables | — | n/a | n/a | replaced by `apigee profile show` / `setup/doctor.sh` |
| `bin/healthcheck` | TZGAO | Environment / API health checks | `/organizations/{org}/environments/{env}/apis/${API_NAME}/health`; `/organizations/{org}/environments/{env}/token` | GET env + deployments | no | `apigee env health` (+ `setup/doctor.sh`) |
| `bin/importApi` | TZGAO | Zip a local proxy and import it (optionally deploy) | `/o/{org}/apis/${APINAME}/revisions/${APIPROXYREV}?validate=true`; `/o/{org}/apis?action=import&name=${APINAME}` | POST .../apis?action=import&name={api} (multipart) | no | `apigee proxy import` (+ `apigee proxy deploy --latest`) |
| `bin/importBundle` | TZGAO | Zip a local proxy and import it (optionally deploy) | — | POST .../apis?action=import&name={api} (multipart) | no | `apigee proxy import` (+ `apigee proxy deploy --latest`) |
| `bin/importDeploy` | TZGAO | Zip a local proxy and import it (optionally deploy) | — | POST .../apis?action=import&name={api} (multipart) | no | `apigee proxy import` (+ `apigee proxy deploy --latest`) |
| `bin/importSHFlow` | TZGAO | Import a shared flow bundle | `/o/{org}/sharedflows?action=import&name=${SHFNAME}` | POST .../sharedflows?action=import&name={sf} | no | `apigee sharedflow import` |
| `bin/list<client>kvms` | TZ | List key value maps | `/o/{org}/e/{env}/keyvaluemaps` | GET .../environments/{env}/keyvaluemaps (also org / proxy scope) | no | `apigee kvm list [--scope ...]` |
| `bin/listApiRevisions` | TZGAO | List / describe proxy revisions | — | GET .../apis/{api}/revisions | partial (apis describe) | `apigee proxy revisions` |
| `bin/listApiVersions` | TZGAO | List / describe proxy revisions | — | GET .../apis/{api}/revisions | partial (apis describe) | `apigee proxy revisions` |
| `bin/listApis` | TZGAO | List API proxies | `/o/{org}/apis` | GET /organizations/{org}/apis | yes (apis list) | `apigee proxy list` |
| `bin/listSFRevisions` | TZGAO | List shared flow revisions | — | GET .../sharedflows/{sf}/revisions | no | `apigee sharedflow revisions` |
| `bin/listevars` | TZ | Print the current session variables | — | n/a | n/a | replaced by `apigee profile show` / `setup/doctor.sh` |
| `bin/mDelApiRevs` | TZ | Delete proxy revision(s) / ranges | — | DELETE .../apis/{api}/revisions/{rev} | no | `apigee proxy delete-revision` (ranges supported) |
| `bin/mDelSFRevs` | TZ | Delete shared flow revision(s) / ranges | — | DELETE .../sharedflows/{sf}/revisions/{rev} | no | `apigee sharedflow delete-revision` / `clean-revisions` |
| `bin/node-chks` | GA | Environment / API health checks | `/o/{org}/e/{env}/apis/mongo`; `/organizations/{o` | GET env + deployments | no | `apigee env health` (+ `setup/doctor.sh`) |
| `bin/parse<client>ln` | TZ | Bulk import maps from key;value files (multi-line PEM aware) | — | POST map + POST/PUT entries | no | `apigee kvm import FILE\|DIR` |
| `bin/parseKVM.sh` | TZ | Bulk import maps from key;value files (multi-line PEM aware) | — | POST map + POST/PUT entries | no | `apigee kvm import FILE\|DIR` |
| `bin/parseLine.sh` | TZ | Bulk import maps from key;value files (multi-line PEM aware) | — | POST map + POST/PUT entries | no | `apigee kvm import FILE\|DIR` |
| `bin/parseresource.awk` | GA | Environment / org resource files | — | X: proxy-level resources only | no | dropped (Edge env resource files; bundle resources travel with proxies) |
| `bin/porp` | TZ | Create/update one KVM entry | `/organizations/{org}/environments/stage/keyvaluemaps/{map}` | POST .../entries, then X: PUT / Edge: POST .../entries/{key} | no | `apigee kvm put MAP KEY (VALUE\|--value-file\|--value-stdin)` |
| `bin/push` | A | Zip a local proxy and import it (optionally deploy) | — | POST .../apis?action=import&name={api} (multipart) | no | `apigee proxy import` (+ `apigee proxy deploy --latest`) |
| `bin/put<client>KVMVals2.sh` | TZ | Bulk import maps from key;value files (multi-line PEM aware) | `/o/{org_name}/environments/{env_name}/keyvaluemaps` | POST map + POST/PUT entries | no | `apigee kvm import FILE\|DIR` |
| `bin/put<client>KVMValues` | TZ | Bulk import maps from key;value files (multi-line PEM aware) | `/o/{org_name}/environments/{env_name}/keyvaluemaps`; `/organizations/{org}/environments/{env}IRON}/keyvaluemaps/${mn}` | POST map + POST/PUT entries | no | `apigee kvm import FILE\|DIR` |
| `bin/put<client>kvmValue` | TZ | Create/update one KVM entry | `/organizations/{org}/environments/{env}/keyvaluemaps/${MAPNAME}/entries`; `/organizations/{org}/environments/{env}/keyvaluemaps/${MAPNAME}/entries/${KVMKEY}` | POST .../entries, then X: PUT / Edge: POST .../entries/{key} | no | `apigee kvm put MAP KEY (VALUE\|--value-file\|--value-stdin)` |
| `bin/sed<client>` | TZ | Strip access_token out of a token response | — | n/a | n/a | replaced (handled inside `apigee token`) |
| `bin/set<client>e` | TZ | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/set<client>x` | TZ | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/setAppsApproved` | TZ | Approve all pending developer apps | `/organizations/{org}/developers`; `/organizations/{org}/developers/$developer/apps` | POST .../developers/{dev}/apps/{app}?action=approve | no | `apigee app approve --all-pending` / `apigee app approve\|revoke --developer` |
| `bin/setOrg` | GA | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/setTRenvE.sh` | T | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/setTRenvX.sh` | T | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/setTargetServer` | TZGAO | Create / configure target server(s) | `/o/{org}/e/{env}/targetservers` | POST .../targetservers; PUT .../targetservers/{name} | no | `apigee target-server create\|update` |
| `bin/setTargetServers` | GA | Create / configure target server(s) | `/o/{org}/e/{env}/targetservers` | POST .../targetservers; PUT .../targetservers/{name} | no | `apigee target-server create\|update` |
| `bin/setcfg` | A | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/setenv.sh` | TZGAO | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/setorg` | TZGAO | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `bin/testAllCalls`, `test/testAllCalls` | TGAO | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `bin/testDeleteCalls`, `test/testDeleteCalls` | TGAO | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `bin/testFindCalls`, `test/testFindCalls` | TGAO | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `bin/testFindCalls.1.out` | TZ | Editor swap files, tmp/out files, awk scratch, .DS_Store, archives | — | n/a | n/a | dropped (artifacts) |
| `bin/testFrame.tmplt`, `test/testFrame.tmplt` | TGAO | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `bin/testGetCalls`, `test/testGetCalls` | TGAO | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `bin/testImportCalls`, `test/testImportCalls` | TGAO | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `bin/testListCalls`, `test/testListCalls` | TGAO | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `bin/ul<client>KVMmaps` | TZ | Bulk import maps from key;value files (multi-line PEM aware) | `/o/{org_name}/environments/{env_name}/keyvaluemaps` | POST map + POST/PUT entries | no | `apigee kvm import FILE\|DIR` |
| `bin/ulApiEnv` | TZGAO | Move an environment: export (and re-upload) TS, vhosts, KVMs, shared flows, proxies | — | composition of the above | no | `apigee env export DIR`; upload half = `kvm import` + `target-server create` + `proxy\|sharedflow import/deploy` |
| `bin/undeploy` | TZGAO | Undeploy a proxy revision | `/o/{org}/apis/${APINAME}/deployments?action=undeploy&env={env}&revision=${VERSION}` | DELETE .../environments/{env}/apis/{api}/revisions/{rev}/deployments | yes (apis undeploy) | `apigee proxy undeploy` |
| `bin/undeployApi` | TZGAO | Undeploy a proxy revision | `/o/{org}/apis/${APINAME}/deployments?action=undeploy&env={env}&revision=${VERSION}` | DELETE .../environments/{env}/apis/{api}/revisions/{rev}/deployments | yes (apis undeploy) | `apigee proxy undeploy` |
| `bin/update` | A | Zip a local proxy and import it (optionally deploy) | — | POST .../apis?action=import&name={api} (multipart) | no | `apigee proxy import` (+ `apigee proxy deploy --latest`) |
| `bin/verifyapigee-commodity.sh` | A | Former-client-specific checks, data or helpers | — | n/a | n/a | dropped (client-specific; generic logic folded into kvm/token/profile) |
| `config/*` (9 files: per-org settings files, backups, conflict copies) | GA | Set org/env/host variables for a session (per org / per client) | — | n/a | n/a | replaced by profiles: `apigee profile use NAME`, `source bin/apigee-env NAME`, config/apigee.env.example |
| `lib/bash_completion` | TGAO | bash completion for the old commands | — | n/a | n/a | dropped (not ported yet; see caveats) |
| `lib/functions`, `lib/functions.2`, `lib/functions.old`, `lib/old/functions.orig`, `lib/old/functions.v.4`, `lib/old/functions.v0`, `lib/old/functions.v3`, `lib/old/functions.v4`, `lib/old/functions.v4a`, `lib/old/functions.v4b`, `lib/old/functions.v5` | TGAO | Shared shell library: option parsing, curl wrapper, debug, delete safety | — | n/a | n/a | replaced by `lib/platform.sh` + `bin/apigee` |
| `lib/jp.sh` | TGAO | Pure-shell JSON parsers | — | n/a | n/a | replaced by `lib/json.sh` (jq, python3 fallback) |
| `lib/json-lib.sh` | TGAO | Pure-shell JSON parsers | — | n/a | n/a | replaced by `lib/json.sh` (jq, python3 fallback) |
| `lib/json-parse-new4DelOrg.sh` | TGAO | Pure-shell JSON parsers | — | n/a | n/a | replaced by `lib/json.sh` (jq, python3 fallback) |
| `lib/json.sh` | TGAO | Pure-shell JSON parsers | — | n/a | n/a | replaced by `lib/json.sh` (jq, python3 fallback) |
| `lib/json_parse.sh` | TGAO | Pure-shell JSON parsers | — | n/a | n/a | replaced by `lib/json.sh` (jq, python3 fallback) |
| `lib/more_functions` | TGAO | Pure-shell JSON parsers | — | n/a | n/a | replaced by `lib/json.sh` (jq, python3 fallback) |
| `lib/<client>testfunctions` | A | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `lib/parseCommandline.old.sh` | T | Shared shell library: option parsing, curl wrapper, debug, delete safety | — | n/a | n/a | replaced by `lib/platform.sh` + `bin/apigee` |
| `lib/pcl.old.sh` | T | Shared shell library: option parsing, curl wrapper, debug, delete safety | — | n/a | n/a | replaced by `lib/platform.sh` + `bin/apigee` |
| `lib/testfunctions`, `test/testfunctions` | TGAO | Old test harness / call smoke tests against live orgs | — | n/a | n/a | replaced by `tests/` (fake curl, both platforms) |
| `data/*` (43 files) | TGAO | Sample request/response payloads and LDAP/SOAP fixtures from past engagements | — | — | n/a | dropped (client data; some files contained credentials) |
| `config/environments/*.d/*` (24 files) | A | Per-org environment config files for past engagements | — | — | n/a | dropped (client org/host names); replaced by profiles |
| `bin/tmp/*` (24 files) | TA | Scratch copies (*.tmp) of scripts and awk files | — | — | n/a | dropped (artifacts) |
