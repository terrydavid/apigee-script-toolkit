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
| `envgroup` | list get (with attachments) | X / hybrid only |
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

## Authentication

Credentials are never accepted as command-line arguments, never echoed, and
never placed in curl's argv: they are written to a private (mode 0600) curl
config file in a per-command temporary directory that is removed on exit.

**Apigee X / hybrid** uses `gcloud auth print-access-token` (set
`CLOUDSDK_CORE_ACCOUNT` to pin an account). Run `gcloud auth login` first.

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
