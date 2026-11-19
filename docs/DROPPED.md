# Dropped legacy scripts

Generated from `docs/INVENTORY.md`. Only 23 rows (logical scripts or file groups) of the legacy
`apigeetools/` tree (commit `5985f5c`, 221 files) have no command in this toolkit. Everything that
the legacy toolkit could do on Apigee X, Edge or Private Cloud (OPDK) now has an `apigee <resource> <verb>`
command: developer/app/credential/product writes (`apigee developer|app|credential|product`), caches,
virtual hosts, keystores (`upload-cert`), users and roles, environment create/delete, OPDK
`org delete` and `server ...`, resource files, `audit`, `kvm flush`, `stats`/`report`/`proxy stale`,
and a raw `apigee raw METHOD PATH` for anything else. See the last column of `docs/INVENTORY.md`.

## Accounting of the old subdirectories

| Old subdirectory | Files | Outcome |
|---|---|---|
| `bin/` (top level) | 73 | migrated to `apigee <resource> <verb>`, replaced by profiles/lib/tests, or dropped (groups below) |
| `bin/dph2/` (36) and `bin/dph3/` (71) | 107 | duplicates by name of `bin/` scripts plus Edge/OPDK admin scripts; each is on the row of its base name, all now ported |
| `lib/` (9) and `lib/old/` (8) | 17 | replaced by `lib/json.sh` / `lib/platform.sh`; `functions.v*` history dropped; `bash_completion` ported |
| `test/` | 13 | `findBroken*` ported as `apigee audit`; `test*` harnesses replaced by `tests/` |
| `data/` | 4 | sample payloads and client data, dropped |
| repo root and `apigeetools/` top level | 6 | rewritten, or dropped as artifacts / client-specific |

No script was lost without a decision.

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

## dropped (use git directly; `apigee proxy compare --dir`)

1 row.

- `bin/dph2/updateSCM`, `bin/updateSCM`: git wrapper for proxy source

## dropped (Apigee BaaS is retired)

1 row.

- `bin/dph3/loadBaasCollection`, `bin/loadBaasCollection`: Load Apigee BaaS collections

## dropped (client data; some files contained credentials)

1 row.

- `data/*` (43 files): Sample request/response payloads and LDAP/SOAP fixtures from past engagements

## dropped (client org/host names); replaced by profiles

1 row.

- `config/environments/*.d/*` (24 files): Per-org environment config files for past engagements
