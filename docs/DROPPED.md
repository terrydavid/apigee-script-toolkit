# Dropped legacy scripts

Generated from `docs/INVENTORY.md`. 100 rows (logical scripts or file groups) were dropped
when the legacy `apigeetools/` tree (commit `5985f5c`, 221 files) was replaced by the unified
toolkit in `154ea66`. Each group below shares one reason. `lib/bash_completion` was dropped at
the time and is now ported as `completions/apigee.bash` (see README, *Shell completion*).

## Accounting of the old subdirectories

Every one of the 221 files in the old tree is covered by an inventory row:

| Old subdirectory | Files | Outcome |
|---|---|---|
| `bin/` (top level) | 73 | migrated to `apigee <resource> <verb>`, replaced by profiles/lib/tests, or dropped (groups below) |
| `bin/dph2/` (36) and `bin/dph3/` (71) | 107 | duplicates by name of `bin/` scripts, plus Edge-only/OPDK admin scripts; each is listed on the row of its base name |
| `lib/` (9) and `lib/old/` (8) | 17 | `lib/json*.sh`, `jp.sh`, `functions*` replaced by `lib/json.sh` / `lib/platform.sh`; `functions.v*` history dropped; `bash_completion` now ported |
| `test/` | 13 | `findBroken*` dropped for now; `test*` harnesses replaced by `tests/` |
| `data/` | 4 | sample payloads and client data, dropped (row `data/*`; one contained a real-looking email) |
| repo root and `apigeetools/` top level (`.gitignore`, `README.md`, `.DT2`, `.vimrc`, `terrydavidhome.code-workspace`) | 6 | rewritten, or dropped as artifacts / client-specific. The workspace file had no inventory row; it belongs with the artifacts | editor file, dropped (artifact). |

No script was lost without a decision. The only real gaps are the four `findBroken*` audits (dropped "for now") and flush-a-map (`cleanKVMKeys`/`cleanKeyValueMap`), which needs two verbs instead of one.

## dropped (artifacts)

9 rows. 

- `.gitignore`, `bin/.gitignore`: Editor swap files, tmp/out files, awk scratch, .DS_Store, archives
- `.tmp`, `bin/.tmp`: Editor swap files, tmp/out files, awk scratch, .DS_Store, archives
- `.vimrc`: Editor swap files, tmp/out files, awk scratch, .DS_Store, archives
- `bin/.importAll.swp`: Editor swap files, tmp/out files, awk scratch, .DS_Store, archives
- `bin/.updateAll.swp`: Editor swap files, tmp/out files, awk scratch, .DS_Store, archives
- `bin/astk.zip`: Editor swap files, tmp/out files, awk scratch, .DS_Store, archives
- `bin/awk.inf`, `lib/awk.inf`: Editor swap files, tmp/out files, awk scratch, .DS_Store, archives
- `bin/testFindCalls.1.out`: Editor swap files, tmp/out files, awk scratch, .DS_Store, archives
- `bin/tmp/*` (24 files): Scratch copies (*.tmp) of scripts and awk files

## dropped (client-specific; generic logic folded into kvm/token/profile)

10 rows. 

- `.DT2`: Former-client-specific checks, data or helpers
- `bin/<client>.AppNames.txt`: Former-client-specific checks, data or helpers
- `bin/ProdEAST`: Former-client-specific checks, data or helpers
- `bin/TS-MyID.xml`: Former-client-specific checks, data or helpers
- `bin/chk1rtr`: Former-client-specific checks, data or helpers
- `bin/chkClient`: Former-client-specific checks, data or helpers
- `bin/clientsValidate`: Former-client-specific checks, data or helpers
- `bin/eula-chk`: Former-client-specific checks, data or helpers
- `bin/eula-telnet`: Former-client-specific checks, data or helpers
- `bin/verifyapigee-commodity.sh`: Former-client-specific checks, data or helpers

## dropped (credential lifecycle out of scope; use apigeecli `apps keys`)

10 rows. 

- `bin/addCredential`, `bin/dph2/addCredential`: Developer app credential / key management
- `bin/auditKeys`, `bin/dph3/auditKeys`: Developer app credential / key management
- `bin/deleteCredential`, `bin/dph3/deleteCredential`: Developer app credential / key management
- `bin/deleteKeys`, `bin/dph3/deleteKeys`: Developer app credential / key management
- `bin/dph2/setCredentialApiProduct`, `bin/setCredentialApiProduct`: Developer app credential / key management
- `bin/dph2/updateCredential`, `bin/updateCredential`, `bin/updateCredntial`: Developer app credential / key management
- `bin/dph3/getCredential`, `bin/getCredential`: Developer app credential / key management
- `bin/dph3/getCredentials`, `bin/getCredentials`: Developer app credential / key management
- `bin/dph3/getKey`, `bin/getKey`: Developer app credential / key management
- `bin/dph3/getKeys`, `bin/getKeys`: Developer app credential / key management

## dropped (OPDK infrastructure; not applicable to X or Edge SaaS)

11 rows. 

- `bin/addEnvironmentServer`, `bin/dph3/addEnvironmentServer`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/deleteEnvironmentServer`, `bin/dph3/deleteEnvironmentServer`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/dph3/chkNodes`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/dph3/getEnvSrvrUuid`, `bin/getEnvSrvrUuid`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/dph3/getEnvironmentServers`, `bin/getEnvironmentServers`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/dph3/getServers`, `bin/getServers`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/dph3/getSrvrFmUuid`, `bin/getSrvrFmUuid`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/dph3/getSrvrIPaddr`, `bin/getSrvrIPaddr`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/dph3/getSrvrIPs`, `bin/getSrvrIPs`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/dph3/getSrvrNames`, `bin/getSrvrNames`: Edge for Private Cloud server / zookeeper / router / node internals
- `bin/dph3/zkDereg`, `bin/zkDereg`: Edge for Private Cloud server / zookeeper / router / node internals

## dropped (use the Apigee UI, apigeecli or BigQuery analytics export)

7 rows. 

- `bin/chkMetrics`: Analytics stats / reports
- `bin/dph2/getAnals`: Analytics stats / reports
- `bin/dph2/getReport`: Analytics stats / reports
- `bin/dph2/getReport.sh`: Analytics stats / reports
- `bin/dph2/getRptTraffic`: Analytics stats / reports
- `bin/dph2/getRptTrafficMonth`: Analytics stats / reports
- `bin/dph2/getStats`: Analytics stats / reports

## dropped (provisioning; use Terraform / gcloud apigee organizations provision)

3 rows. 

- `bin/crOrgEnv`, `bin/dph2/crOrgEnv`: Create / delete organizations or environments
- `bin/createEnvironment`, `bin/dph3/createEnvironment`: Create / delete organizations or environments
- `bin/deleteEnvironment`, `bin/dph3/deleteEnvironment`: Create / delete organizations or environments

## dropped (app provisioning is out of scope; use apigeecli `apps create/delete` or the portal)

7 rows. 

- `bin/createApp`, `bin/dph2/createApp`: Create / load / delete developer apps
- `bin/createApps`, `bin/dph3/createApps`: Create / load / delete developer apps
- `bin/deleteApp`, `bin/dph3/deleteApp`: Create / load / delete developer apps
- `bin/deleteAppsBulk`: Create / load / delete developer apps
- `bin/dph2/createAppfromFile`: Create / load / delete developer apps
- `bin/dph2/loadApp`, `bin/loadApp`: Create / load / delete developer apps
- `bin/dph2/postApp`: Create / load / delete developer apps

## dropped (Edge-only cache administration; X caches are implicit)

5 rows. 

- `bin/createCache`, `bin/dph3/createCache`: Create / delete / inspect caches
- `bin/createCaches`, `bin/dph3/createCaches`: Create / delete / inspect caches
- `bin/deleteCache`, `bin/dph3/deleteCache`: Create / delete / inspect caches
- `bin/dph2/getCache`, `bin/getCache`: Create / delete / inspect caches
- `bin/dph2/getCacheEntries`, `bin/getCacheEntries`: Create / delete / inspect caches

## dropped (developer provisioning out of scope; use apigeecli `developers`)

3 rows. 

- `bin/createDeveloper`, `bin/dph2/createDeveloper`: Create / delete developers
- `bin/deleteDeveloper`, `bin/dph3/deleteDeveloper`: Create / delete developers
- `bin/dph3/createDeveloperfromFile.sh`: Create / delete developers

## dropped (Edge-only write; X routing uses envgroups managed via gcloud/Terraform)

7 rows. 

- `bin/createSslVirtualHost`, `bin/dph2/createSslVirtualHost`: Create / update / delete virtual hosts
- `bin/createVirtualHost`, `bin/dph2/createVirtualHost`: Create / update / delete virtual hosts
- `bin/deleteVirtualHost`, `bin/dph2/deleteVirtualHost`: Create / update / delete virtual hosts
- `bin/dph2/createManySSLVHosts`: Create / update / delete virtual hosts
- `bin/dph2/createManyVHosts`: Create / update / delete virtual hosts
- `bin/dph2/updateVirtualHost`: Create / update / delete virtual hosts
- `bin/dph3/putVHost`: Create / update / delete virtual hosts

## dropped (Edge RBAC; X uses IAM)

8 rows. 

- `bin/createUserRole`, `bin/dph3/createUserRole`: User roles / RBAC administration
- `bin/deleteUserRole`, `bin/dph3/deleteUserRole`: User roles / RBAC administration
- `bin/dph2/addUserRole`: User roles / RBAC administration
- `bin/dph2/createUser`: User roles / RBAC administration
- `bin/dph3/deleteUser`: User roles / RBAC administration
- `bin/dph3/getUserRoles`, `bin/getUserRoles`: User roles / RBAC administration
- `bin/dph3/listRBACResources`, `bin/listRBACResources`: User roles / RBAC administration
- `bin/dph3/listUserRoles`, `bin/listUserRoles`: User roles / RBAC administration

## dropped (destructive org teardown; out of scope)

2 rows. 

- `bin/delete-org.sh`: Delete everything in an org (teardown)
- `bin/dph3/delOrg`: Delete everything in an org (teardown)

## dropped (whole-proxy delete is rare and destructive; use apigeecli `apis delete`)

1 rows. 

- `bin/deleteApi`, `bin/dph3/deleteApi`: Delete an entire proxy

## dropped (use `curl -H "$(apigee token --header)" ...`)

2 rows. 

- `bin/dph2/getApigeeJson`, `bin/getApigeeJson`: Raw GET of any management resource
- `bin/dph2/getApigeeXml`, `bin/getApigeeXml`: Raw GET of any management resource

## dropped (use git directly; `apigee proxy compare --dir`)

1 rows. 

- `bin/dph2/updateSCM`, `bin/updateSCM`: git wrapper for proxy source

## dropped (write path for TLS material; use apigeecli `keystores`/`aliases` or Terraform)

1 rows. 

- `bin/dph2/uploadKeyCert`: Upload a key/cert to a keystore

## dropped for now (candidate skill: consistency audit)

4 rows. 

- `bin/dph3/findBroken.tmplt`, `bin/findBroken.tmplt`, `test/findBroken.tmplt`: Find orphaned products / proxies / apps / developers
- `bin/dph3/findBrokenApiProxies`, `bin/findBrokenApiProxies`, `test/findBrokenApiProxies`: Find orphaned products / proxies / apps / developers
- `bin/dph3/findBrokenApps`, `bin/findBrokenApps`, `test/findBrokenApps`: Find orphaned products / proxies / apps / developers
- `bin/dph3/findBrokenProducts`, `bin/findBrokenProducts`, `test/findBrokenProducts`: Find orphaned products / proxies / apps / developers

## dropped (Edge company scope; no X equivalent). Env/org/proxy scopes via `apigee kvm get`

1 rows. 

- `bin/dph3/getKVMValComp`, `bin/getKVMValComp`: Get a company-scoped KVM value (Edge monetization)

## dropped (Edge env resource files; bundle resources travel with proxies)

4 rows. 

- `bin/dph3/getResources`, `bin/getResources`: Environment / org resource files
- `bin/dph3/loadResource`, `bin/loadResource`: Environment / org resource files
- `bin/getResourceFiles`: Environment / org resource files
- `bin/parseresource.awk`: Environment / org resource files

## dropped (Apigee BaaS is retired)

1 rows. 

- `bin/dph3/loadBaasCollection`, `bin/loadBaasCollection`: Load Apigee BaaS collections

## dropped (not ported yet; see caveats)

1 rows. 

- `lib/bash_completion`: bash completion for the old commands

## dropped (client data; some files contained credentials)

1 rows. 

- `data/*` (43 files): Sample request/response payloads and LDAP/SOAP fixtures from past engagements

## dropped (client org/host names); replaced by profiles

1 rows. 

- `config/environments/*.d/*` (24 files): Per-org environment config files for past engagements
