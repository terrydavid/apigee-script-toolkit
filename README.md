# apigee-toolkit

A small, dependency-light shell CLI for day-to-day Apigee administration that
works the same way against **Apigee X / hybrid** and **Apigee Edge**.

It replaces a large collection of one-script-per-call legacy tools with a
single `apigee` dispatcher, shared auth and request handling, profiles, and
an offline test suite. See [docs/INVENTORY.md](docs/INVENTORY.md) for how every
legacy script maps to a command here (or why it was dropped).

Prefer `gcloud apigee` when it already does the job; this toolkit focuses on
what gcloud does not cover (shared flows, KVMs, target servers, keystores,
revision clean-up, bundle diffing, environment export, Edge-only resources).

## Quick start

```bash
setup/install.sh --check          # what is missing? (read-only)
setup/install.sh                  # install missing tools with Homebrew (asks first)

cp config/profiles/example-x.env config/profiles/my-x.env   # edit org/env
bin/apigee profile use my-x
setup/doctor.sh                   # tools, config, auth and a read-only org GET
setup/gcloud-login.sh             # wrong account or 403s? reset and verify the gcloud login
setup/gcloud-impersonate.sh       # no more hourly re-logins: use a service account (see Authentication)

bin/apigee proxy list
bin/apigee proxy deployed my-proxy --all-envs
```

Put `bin/` on your `PATH`, or `source bin/apigee-env my-x` (bash or zsh),
which exports the profile into the current shell and adds `bin/` to `PATH`.

Requirements: bash 3.2+ (the macOS default works), curl, and either `jq` or
`python3` for JSON. Apigee X / hybrid also needs the Google Cloud SDK
(`gcloud`). `unzip`/`zip` and `diff` are used by bundle commands.

## Usage

```text
apigee [global options] <resource> <verb> [options]
apigee --help | apigee <resource> --help | apigee <resource> <verb> --help
```

| Resource | Verbs | Platforms |
|----------|-------|-----------|
| `proxy` | list revisions latest deployed download import deploy undeploy delete-revision clean-revisions compare | both |
| `sharedflow` | same as `proxy` | both |
| `kvm` | list get create delete put export import (`--scope env\|org\|proxy:NAME`) | both |
| `target-server` | list get create update delete | both |
| `keystore`, `truststore` | list get | both |
| `app` | list get approve revoke (`approve --all-pending`) | both |
| `developer`, `product` | list get | both |
| `env` | list get health export | both |
| `org` | get | both |
| `cache` | list clear | Edge only |
| `virtualhost` | list get | Edge only |
| `user` | list | Edge only |
| `envgroup` | list get attachments attach (attach is mutating) | X / hybrid only |
| `instance` | list attachments attach | X / hybrid only. An environment runs deployments only once it is attached to an instance; an unattached one shows every deployment as `ERROR` ("no instances are reporting status for this environment"). `attach` uses `--env`, takes several minutes and asks for confirmation. |
| `token` | print an access token (`--header` for an `Authorization:` line) | both |
| `profile` | list use show current clear | n/a |
| `doctor` | runs `setup/doctor.sh` | both |

Global options can appear anywhere on the command line:

| Option | Meaning |
|--------|---------|
| `--platform x\|hybrid\|edge` | Override `APIGEE_PLATFORM` |
| `--org ORG`, `--env ENV` | Override `APIGEE_ORG` / `APIGEE_ENV` |
| `--profile NAME` | Load a profile for this command only |
| `-n`, `--dry-run` | Run read requests, print every mutating request instead of sending it |
| `-y`, `--yes` | Skip confirmation prompts on mutating verbs |
| `--debug` | Log requests to stderr (credentials are never logged) |
| `--json-engine jq\|python` | Force the JSON engine (default: jq, else python3) |

Mutating verbs ask for confirmation on a terminal. In scripts (no TTY) they
refuse to run unless `--yes` (or `--dry-run`) is given.

A command that has no equivalent on the selected platform fails with a clear
`not supported on Apigee X/hybrid` (or `Apigee Edge`) message instead of
sending a request.

### Examples

```bash
# Revisions
apigee proxy latest orders
apigee proxy download orders --deployed -o orders.zip
apigee proxy import orders ./orders/apiproxy --validate
apigee proxy deploy orders --latest --yes
apigee proxy delete-revision orders 3-7          # skips deployed revisions
apigee proxy clean-revisions --all --keep 5 --dry-run
apigee proxy compare orders 12 14                # diff two revisions
apigee proxy compare orders 14 --dir ./orders    # revision vs. a local checkout

# KVMs
apigee kvm list --scope org
apigee kvm get settings timeout
apigee kvm put settings tls-cert --value-file cert.pem
printf %s "$VALUE" | apigee kvm put settings api-key --value-stdin
apigee kvm export --out kvm-export               # every env-scoped map
apigee kvm import kvm-export --env prod --yes

# Environments
apigee env health
apigee env export ./snapshot-test                # target servers, KVMs, vhosts (Edge), deployed bundles

# Apps
apigee app approve --all-pending --dry-run     # only status "pending"; revoked apps are skipped and listed
```

Options of a verb may be given before or after its positional arguments
(`apigee proxy deployed --all-envs orders` works like
`apigee proxy deployed orders --all-envs`).

## Configuration

Settings are plain `KEY=value` files; see
[config/apigee.env.example](config/apigee.env.example) for every variable.

Precedence (lowest to highest):

1. `config/apigee.env` in the repo (git-ignored)
2. `~/.config/apigee-toolkit/apigee.env`
3. the current profile (`apigee profile use NAME` or `APIGEE_PROFILE`) — only fills variables that are not already set
4. variables already in the environment
5. `--profile NAME` on the command line
6. `--org`, `--env`, `--platform` flags

Profiles live in `config/profiles/NAME.env` (git-ignored except the
`example-*` files) or `~/.config/apigee-toolkit/profiles/NAME.env`.

```bash
apigee profile list
apigee profile use my-edge        # remembered in ~/.config/apigee-toolkit/current-profile
apigee profile show               # prints settings; secret-looking values show as <redacted>
apigee profile clear
source bin/apigee-env my-edge     # bash or zsh; `source bin/apigee-env --unset` to undo
```

`apigee profile show` redacts the value of every variable whose name contains
`SECRET`, `PASSWORD`, `PASSCODE`, `TOKEN`, `CLIENT`, `MFA` or `KEY` (any case),
for example `APIGEE_EDGE_SSO_CLIENT` and `APIGEE_EDGE_MFA_CODE`. This also
hides harmless settings such as `APIGEE_EDGE_TOKEN_URL`.

Key variables: `APIGEE_PLATFORM` (`x`, `hybrid`, `edge`), `APIGEE_ORG`,
`APIGEE_ENV`, `APIGEE_X_API_URL`, `APIGEE_EDGE_MGMT_URL`, `APIGEE_EDGE_AUTH`,
`APIGEE_EDGE_USER`, `APIGEE_EDGE_TOKEN_URL`, `APIGEE_KVM_READER_URL`.

## Shell completion

`setup/install-completion.sh` appends a marked block to `~/.bashrc` that sources
`completions/apigee.bash` (`--zsh` uses `~/.zshrc` through bashcompinit, `--rc FILE` another file,
`--uninstall` removes the block; re-running never duplicates it). It completes resources and
aliases, verbs, global options and their values, per-verb options (for example the `env import`
flags) and profile names. Legacy scripts that were dropped are listed in `docs/DROPPED.md`.

## Authentication

Credentials are never accepted as command-line arguments, never echoed, and
never placed in curl's argv: they are written to a private (mode 0600) curl
config file in a per-command temporary directory that is removed on exit.

**Apigee X / hybrid** uses `gcloud auth print-access-token` (set
`CLOUDSDK_CORE_ACCOUNT` to pin an account). Run `gcloud auth login` first.

### Fixing gcloud authentication problems (Apigee X / hybrid)

**The identity check.** When `CLOUDSDK_CORE_ACCOUNT` is set, the toolkit asks
Google's tokeninfo endpoint whose token gcloud handed over and refuses to
continue if it is not that account's. If you impersonate a service account (see
below), the token must be the service account's instead. The check runs before
the first Apigee call, so a wrong identity can never create or change anything.
`env import` authenticates once, before its confirmation prompt, so a mismatch
stops the whole import with a single message. The check fails open (it does
nothing if tokeninfo cannot be reached). Skip it with
`APIGEE_SKIP_IDENTITY_CHECK=1`.

```
apigee: error: gcloud gave a token for 'you@gmail.com', but CLOUDSDK_CORE_ACCOUNT is 'you@corp.example'.
```

**What goes wrong.** gcloud keeps one stored credential per account name. After
a browser login with several Google accounts signed in, the credential saved
under `you@corp.example` can belong to a different account. gcloud then returns
that other account's token, and Apigee answers 403 (the other account has no
rights on the org), or the identity check stops you. Confirm it with:

```bash
curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$(gcloud auth print-access-token --account=you@corp.example)" | grep email
```

If the email shown is not `you@corp.example`, use the reset script.

#### `setup/gcloud-login.sh` - reset and verify a login

```bash
setup/gcloud-login.sh [ACCOUNT]          # default ACCOUNT: $CLOUDSDK_CORE_ACCOUNT
setup/gcloud-login.sh --check [ACCOUNT]  # run only the checks, change nothing
```

It does four things in order:

1. Revokes the stored credential for ACCOUNT (other accounts are untouched).
2. Deletes gcloud's token cache (`~/.config/gcloud/access_tokens.db`).
3. Runs `gcloud auth login ACCOUNT --no-launch-browser`, which prints a URL.
   **Open that URL in a private/incognito window** and sign in as ACCOUNT only.
   A normal window with several Google accounts is what caused the problem.
4. Checks that the token for `--account=ACCOUNT` and the default token both
   belong to ACCOUNT, that `credentials.db` holds one entry for it (needs
   `sqlite3`), and that no other account is selected in this shell.

It exits 0 when every check passes, 1 when one fails (the output says which
and what to do), and 2 for a usage problem. Put it on your `PATH` if you like:
`ln -s "$PWD/setup/gcloud-login.sh" ~/bin/gcloud-login`.

#### `setup/gcloud-impersonate.sh` - stop depending on a browser login

A login token expires after an hour, and the credential behind it can be the
wrong one. With service-account impersonation, gcloud uses your login only to
ask Google for a short-lived token for a dedicated service account, and it does
that again on every call. There is no hourly re-login, and every request is made
as the same identity. (Each token still lasts one hour; gcloud simply gets a new
one when needed. A longer token lifetime needs an organization policy.)

```bash
setup/gcloud-impersonate.sh -n --project my-org --user you@corp.example   # preview
setup/gcloud-impersonate.sh    --project my-org --user you@corp.example   # do it (asks first)
setup/gcloud-impersonate.sh --undo                                        # stop impersonating
```

| Option | Meaning |
|--------|---------|
| `--project ID` | Project holding the Apigee org (default: gcloud's current project). |
| `--user ACCOUNT` | Person allowed to impersonate (default: `$CLOUDSDK_CORE_ACCOUNT`). |
| `--sa NAME` | Service account name (default `apigee-toolkit`). |
| `--read-only` | Grant `roles/apigee.readOnlyAdmin` instead of `roles/apigee.admin`. |
| `--role ROLE` | Grant this role instead; repeat for several (use a narrower role than admin if you can). |
| `--no-config` | Leave gcloud's configuration alone and print the command to enable it later. |
| `-y`, `-n` | Skip the confirmation / print the commands and change nothing. |
| `--undo` | Run `gcloud config unset auth/impersonate_service_account`. |

What it changes, each step safe to repeat:

1. Enables the IAM Service Account Credentials API on the project.
2. Creates the service account `NAME@PROJECT.iam.gserviceaccount.com` if missing.
3. Grants that service account its Apigee role on the project.
4. Grants `--user` `roles/iam.serviceAccountTokenCreator` on that service
   account only (not project-wide).
5. Requests a token and confirms with tokeninfo that it belongs to the service
   account. IAM changes can take a few minutes to apply, so it retries for up to
   about three minutes. If this fails, gcloud is left unchanged (not switched to
   impersonation) and everything created so far is kept; run the script again to
   retry just the check.
6. Only after that passes, sets `auth/impersonate_service_account` in the
   **active** gcloud configuration, so every gcloud command in that configuration
   impersonates. To limit it to one shell instead, use `--no-config` and
   `export CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT=SA_EMAIL`.

You need permission to create service accounts and edit the project's IAM policy
(for example Owner). Impersonation still needs a valid login for `--user`; if
that stored credential is the wrong one, you will get a clear permission error
instead of a silently wrong identity. Run `setup/gcloud-login.sh` first if so.

**Apigee Edge** supports three modes (`APIGEE_EDGE_AUTH`):

| Mode | How |
|------|-----|
| `oauth` (default) | Password grant against the Edge OAuth endpoint; the token is cached in `~/.cache/apigee-toolkit` (mode 0600) until it expires. SSO orgs set `APIGEE_EDGE_TOKEN_URL` to their zone and provide `APIGEE_EDGE_PASSCODE`. |
| `basic` | HTTP basic auth with `APIGEE_EDGE_USER` and the password. |
| `token` | Use a pre-fetched bearer token from `APIGEE_TOKEN`. |

Secrets are read from the environment of the current shell, or from the macOS
Keychain:

```bash
security add-generic-password -U -s apigee-toolkit-edge -a "$APIGEE_EDGE_USER" -w
# OAuth client credentials ("client_id:client_secret") for the Edge token endpoint
security add-generic-password -U -s apigee-toolkit-edge-sso-client -a client -w
```

Environment alternatives: `APIGEE_EDGE_PASSWORD`, `APIGEE_EDGE_SSO_CLIENT`,
`APIGEE_EDGE_MFA_CODE`, `APIGEE_EDGE_PASSCODE`, `APIGEE_TOKEN`.

`apigee token` prints the current access token, so ad-hoc calls stay possible:

```bash
curl -sS -H "$(apigee token --header)" "https://apigee.googleapis.com/v1/organizations/my-org/environments"
```

### No more logins: service-account key

`setup/gcloud-sa-key.sh --yes` (run once, while you have a working gcloud login) creates a key for
`apigee-toolkit@PROJECT.iam.gserviceaccount.com`, saves it as `~/.config/apigee-toolkit/sa-key.json`
(mode 600, outside the repository, never printed) and checks that it yields a token. From then on
`bin/apigee` and `tools/compare_envs.py` sign in from that file for their own calls, so no browser
login can expire or be saved under the wrong account; your own gcloud login is untouched. Set
`APIGEE_SA_KEY=/path/key.json` to use a key elsewhere. `--check` tests the saved key, `--force`
replaces it, `--remove` deletes the file and the service account's keys. If your organization
enforces `constraints/iam.disableServiceAccountKeyCreation` the script says so and an organization
admin must allow keys for the project. The service account is created by
`setup/gcloud-impersonate.sh` (add `--no-config`) and needs `roles/apigee.admin`.

## KVM export formats

`apigee kvm export` writes one file per map.

* `--format json` (default): `{"name": "...", "encrypted": true|false, "entries": [{"name": "...", "value": "..."}]}`
* `--format lines`: the legacy `key;value` format, one entry per line. A value
  that starts with `-----BEGIN` continues until the matching `-----END` line,
  so PEM blocks round-trip. CRLF line endings are accepted on import.

Apigee Edge does not return values of **encrypted** maps. To export them,
deploy a small reader proxy that answers `GET <url>?mapname=MAP&key=KEY` with
the raw value and set `APIGEE_KVM_READER_URL` (or `--reader-url`). Keep such
a proxy locked down; it exposes secrets by design.

On import, existing entries are updated (X uses `PUT .../entries/KEY`, Edge
uses `POST .../entries/KEY`), missing maps are created unless `--no-create`.

`apigee kvm import` refuses to write anything if any value in any of the given
files consists only of asterisks (`*****` is how Edge masks encrypted values),
so a masked export cannot overwrite real secrets. It lists the affected files
and keys. Pass `--allow-masked` to import such values anyway.

`apigee kvm get MAP KEY` prints the value byte-for-byte, including trailing
newlines (PEM files keep their final newline); `--reader-url` values are
preserved the same way in `get` and `export`.

## Platform differences

| Feature | X / hybrid | Edge |
|---------|------------|------|
| Base URL | `https://apigee.googleapis.com/v1` | `https://api.enterprise.apigee.com/v1` |
| Auth | gcloud token | OAuth password grant, basic, or token |
| KVM entries | paginated `entries` API; values always readable | values of encrypted maps hidden |
| `kvm create --no-encrypt` | not supported (always encrypted) | supported |
| `proxy deploy --service-account` | supported | not supported |
| Caches, virtual hosts, users | not supported | supported |
| Environment groups | supported | not supported |

## Tools

* `tools/compare_envs.py --org ORG SRC DST` — read-only check that DST has what SRC has:
  the same proxy and shared flow revisions deployed (and each READY, since a deploy can be
  accepted and still fail), the same target servers, and the same KVMs with equal entry
  counts. Uses `APIGEE_TOKEN` or gcloud. Run it after `env import`.
* `tools/cvtPEM2JWK.js` — convert a PEM public key into a JWK (with thumbprint)
  for JWT/JWKS configuration. `cd tools && npm install`, then
  `node cvtPEM2JWK.js key.pem`.
* `setup/install.sh --optional` also offers `apigeelint` (bundle linter) and
  explains how to install `apigeecli` for operations outside this toolkit
  (app/credential provisioning, analytics, whole-proxy delete).

## Testing

```bash
tests/run.sh
```

The suite is plain bash. A fake `curl` on `PATH` records every request (method,
URL, headers, curl config, body) and serves canned responses, with fake
`gcloud` and `security` (Keychain) commands, so no network or real org is
needed. Every test runs once with jq and once with the python3 JSON engine.
Tests cover both platforms: URL building, auth (including that secrets never
reach argv), dry-run and confirmation safety, KVM export/import round trips,
and bundle revision handling.

Linting: `shellcheck bin/* lib/*.sh libexec/*.sh setup/*.sh tests/*.sh tests/fakebin/*`.

### Live check (manual, read-only)

`tests/live_check.sh` smoke-tests one proxy against a real Apigee X org. It is
not part of `tests/run.sh` because it needs network access and a gcloud login.
It only issues GET requests.

```bash
bash tests/live_check.sh [PROXY] [ORG] [ENV]     # default: hello-apigee-api corp-apigee dev
CLOUDSDK_CORE_ACCOUNT=you@example.com bash tests/live_check.sh   # pin the gcloud account
```

It prints PASS/FAIL per check and writes the full output to
`tests/live_check_<env>.log` (git-ignored; it contains org details).

Troubleshooting a failing live check:

- **"Reauthentication failed"**: the stored gcloud login expired. Run
  `gcloud auth login ACCOUNT --force`. Without `--force`, gcloud reuses the
  stored credential and nothing changes.
- **403 `PERMISSION_DENIED` ... "(or it may not exist)"**: that account cannot
  see the project. Check with
  `CLOUDSDK_CORE_ACCOUNT=ACCOUNT gcloud projects list --format="table(projectId,name)"`;
  if the project is missing, refresh the login as above. The Apigee org name
  is the project **ID**, which can differ from the project's display name.
- gcloud's active account can differ from what you expect; pin it with
  `CLOUDSDK_CORE_ACCOUNT` rather than relying on
  `gcloud config set account`.

## Migrating from the legacy scripts

* Session scripts that exported org/host variables become profiles.
* `getXxx`/`listXxx` scripts become `apigee <resource> list|get`.
* Bulk KVM scripts become `apigee kvm export|import`; the legacy `key;value`
  files are still readable with `--format lines`.
* Revision clean-up scripts become `apigee proxy|sharedflow delete-revision`
  and `clean-revisions`, which never delete deployed revisions.
* Product writes are left to `gcloud apigee products`.

The full mapping, including dropped scripts and reasons, is in
[docs/INVENTORY.md](docs/INVENTORY.md).

### Live sweep of every read command (manual, read-only)

```bash
python3 tests/live_readonly.py run --org ORG --env ENV --platform x --gcloud
```

Runs every GET-style command (list/get/revisions/latest/deployed/health...) against
real names it discovers (`--sample N`, default 2), optionally cross-checks counts with
`gcloud apigee ... list`, and writes `tests/live_all/report.md` and `results.json`
(git-ignored). Each row shows the legacy toolkit script it replaces (from
`docs/INVENTORY.md`). The report groups failures by cause (auth, permission, 404, 5xx,
timeout), flags slow and empty results, and lists gcloud count mismatches.
Command output is never saved, developer emails and app ids are masked
(`--no-redact` to show them), and file-writing commands are skipped.
`python3 tests/live_readonly.py report` re-renders the report from the last run.

### Export and import a whole environment

```bash
apigee env export ./snap --env dev            # target servers, KVMs, keystore metadata,
                                              # deployed proxies/shared flows, env groups (X)
                                              # or caches/virtual hosts (Edge), plus the org's
                                              # developers, API products and apps
apigee env import ./snap --env test --deploy  # recreate it somewhere else
```

- Org-level data can also be moved on its own: `apigee developer|product|app export [DIR]`
  and `apigee developer|product|app import DIR`.
- Opt out of parts with `--no-bundles --no-kvms --no-keystores --no-developers --no-products --no-apps`
  (import: `--no-targetservers --no-kvms --no-developers --no-products --no-apps --no-bundles`).
- Import creates what is missing and skips what exists; `--overwrite` updates instead.
  `--deploy` deploys each imported bundle (shared flows first). It asks for one confirmation
  (`--yes` to skip, `-n` to preview). A bundle whose deployment fails is reported and the
  import carries on with the rest. Keystore contents, env groups, virtual hosts and caches
  are exported for reference but not imported (Apigee does not export private keys).
- **Importing into the same org** (for example dev to another environment of the same org):
  org-level items (developers, products, apps) already exist and are skipped, and uploading
  a bundle would only add a duplicate revision of a proxy that is already there. Use
  `--existing-revisions --deploy` to skip the upload and deploy the revision named in each
  file (`NAME-revN.zip`) to the target environment instead. This also avoids the "belongs
  to space" 403, which blocks uploads, not deployments.
- **Deployment service account (Apigee X):** bundles that need a service account (error
  `MISSING_SERVICE_ACCOUNT`) are deployed with `--service-account EMAIL` on `env import`,
  as with `proxy deploy`. The export does not record which service account each
  deployment used; `--service-account-from ENV` reads it from the deployment of the same
  revision in ENV (for example `dev`) and gives each bundle its own, or none if it had none.
- **App credentials:** consumer keys and secrets are shown as `"<redacted>"` by `app get`,
  `app export` and `env export`. Add `--show-credentials` to include them. Exports made that
  way are restored on import (the key Apigee generates is removed); redacted ones are not,
  so the imported app gets a new key.
- Export files are created private (mode 600, directories 700). KVM values and exported
  credentials are secrets: keep the export out of version control.
- `tests/live_readonly.py run --write-files DIR [--show-credentials]` also runs the
  file-writing commands during the live sweep and reports what was written (never contents).

