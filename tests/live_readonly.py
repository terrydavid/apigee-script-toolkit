#!/usr/bin/env python3
"""Live, READ-ONLY sweep of every GET-style `apigee` command, plus analysis.

Not part of tests/run.sh (needs network and a gcloud/Edge login):

    python3 tests/live_readonly.py run    --org ORG --env ENV [--platform x|edge]
    python3 tests/live_readonly.py report [--out DIR]

`run` executes an allow-list of read verbs (list/get/revisions/latest/deployed/
health/...) after discovering a few real names to query, optionally cross-checks
counts against `gcloud apigee ... list`, and writes results.json + report.md.
`report` re-renders report.md from results.json.

Every row of the report shows the legacy toolkit script(s) that the command
replaces, read from docs/INVENTORY.md.

Safety:
  * only the allow-list below is ever executed; mutating verbs are not in it;
  * command output is NOT saved (it can contain secrets: KVM values, app keys);
    only exit code, timing, size, line count and the first error line are kept;
  * developer emails and app ids are masked unless --no-redact is given.
Commands that write files (kvm export, proxy/sharedflow download, env export) are
skipped unless --write-files DIR is given; they then write under DIR (mode 700, files
600) and the report lists what was written, never its contents. Exports of KVMs and
(with --show-credentials) app keys and secrets are secrets: keep DIR private.
"""
import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APIGEE = os.path.join(ROOT, "bin", "apigee")
INVENTORY = os.path.join(ROOT, "docs", "INVENTORY.md")

EDGE_ONLY = {"cache", "virtualhost", "user"}
X_ONLY = {"envgroup"}


# --------------------------------------------------------------------------
# Legacy mapping from docs/INVENTORY.md
# --------------------------------------------------------------------------
def load_legacy_map(path=INVENTORY):
    """Return {(resource, verb): [legacy script names]} from the inventory."""
    mapping = {}
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return mapping
    for line in text.splitlines():
        if not line.startswith("| `"):
            continue
        cells = [c.strip() for c in line.replace("\\|", "\x00").split(" | ")]
        if len(cells) < 4:
            continue
        legacy = re.findall(r"`([^`]+)`", cells[0].lstrip("| "))
        names = []
        for item in legacy:
            base = item.split("/")[-1]
            if base and base not in names:
                names.append(base)
        last = cells[-1].rstrip(" |").replace("\x00", "|")
        for span in re.findall(r"`(apigee [^`]+)`", last):
            words = span.split()
            if len(words) < 2:
                continue
            res = words[1]
            verb = words[2] if len(words) > 2 and re.match(r"^[a-z][a-z-]*$", words[2]) else ""
            targets = [(res, verb)]
            if res == "proxy":  # sharedflow has the same verbs
                pass
            for key in targets:
                cur = mapping.setdefault(key, [])
                for n in names:
                    if n not in cur:
                        cur.append(n)
    return mapping


def legacy_for(mapping, res, verb):
    names = mapping.get((res, verb)) or []
    if not names and res == "sharedflow":
        names = mapping.get(("proxy", verb)) or []
    return names


# --------------------------------------------------------------------------
# Running commands
# --------------------------------------------------------------------------
def classify(rc, err, timed_out):
    if timed_out:
        return "timeout"
    if rc == 0:
        return "ok"
    e = err or ""
    if re.search(r"HTTP 401|print-access-token failed|Reauthentication", e):
        return "auth"
    if "HTTP 403" in e:
        return "permission"
    if "HTTP 404" in e:
        return "not_found"
    if "HTTP 429" in e:
        return "rate_limited"
    if re.search(r"HTTP 5\d\d", e):
        return "server_error"
    if "unhealthy deployments" in e or "not reachable" in e:
        return "unhealthy"
    return "other"


def first_error(err):
    for line in (err or "").splitlines():
        line = line.strip()
        if line and not line.startswith("curl:"):
            line = re.sub(r"Bearer [A-Za-z0-9._~+/=-]+", "Bearer <redacted>", line)
            return line[:200]
    return ""


class Runner:
    def __init__(self, args):
        self.args = args
        self.rows = []
        self.legacy = load_legacy_map()
        self.mask = {}
        env = dict(os.environ)
        env.pop("CDPATH", None)
        env["APIGEE_YES"] = ""  # never auto-confirm anything
        self.env = env
        self.base = [APIGEE, "--org", args.org, "--platform", args.platform]
        if args.env:
            self.base += ["--env", args.env]

    def show(self, value, kind):
        """Mask developer emails / app ids in what we record."""
        if self.args.no_redact or kind is None:
            return value
        key = (kind, value)
        if key not in self.mask:
            self.mask[key] = "<%s-%d>" % (kind, 1 + sum(1 for k in self.mask if k[0] == kind))
        return self.mask[key]

    def exec(self, argv, timeout=None):
        t0 = time.monotonic()
        timed_out = False
        try:
            p = subprocess.run(
                self.base + argv, stdin=subprocess.DEVNULL, capture_output=True,
                text=True, env=self.env, timeout=timeout or self.args.timeout)
            rc, out, err = p.returncode, p.stdout, p.stderr
        except subprocess.TimeoutExpired as e:
            rc, out, err, timed_out = 124, (e.stdout or ""), (e.stderr or ""), True
            if isinstance(out, bytes):
                out = out.decode("utf-8", "replace")
            if isinstance(err, bytes):
                err = err.decode("utf-8", "replace")
        ms = int((time.monotonic() - t0) * 1000)
        return rc, out, err, ms, timed_out

    def record(self, res, verb, argv, shown_args, rc, out, err, ms, timed_out, note=""):
        cat = classify(rc, err, timed_out)
        lines = len([l for l in out.splitlines() if l.strip()])
        self.rows.append({
            "command": " ".join(["apigee", res, verb] + shown_args).strip(),
            "resource": res, "verb": verb,
            "legacy": legacy_for(self.legacy, res, verb),
            "status": "PASS" if rc == 0 else "FAIL",
            "category": cat, "exit": rc, "ms": ms,
            "bytes": len(out.encode("utf-8")), "lines": lines,
            "error": first_error(err) if rc else "", "note": note,
        })
        return out

    def run(self, res, verb, args=(), mask=None, note=""):
        argv = [res, verb] + list(args)
        shown = [self.show(a, mask[i]) if mask and mask[i] else a for i, a in enumerate(args)]
        rc, out, err, ms, to = self.exec(argv)
        return self.record(res, verb, argv, shown, rc, out, err, ms, to, note), rc

    def skip(self, res, verb, args, why):
        self.rows.append({
            "command": " ".join(["apigee", res, verb] + list(args)).strip(),
            "resource": res, "verb": verb, "legacy": legacy_for(self.legacy, res, verb),
            "status": "SKIP", "category": "skipped", "exit": None, "ms": 0,
            "bytes": 0, "lines": 0, "error": "", "note": why})

    def names(self, out):
        return [l.strip() for l in out.splitlines() if l.strip()][: self.args.sample]


def sweep(args):
    r = Runner(args)
    edge = args.platform == "edge"
    n = args.sample

    out, rc = r.run("token", "print")
    # token output is a secret; run() recorded only metadata.
    r.run("org", "get")
    envs, _ = r.run("env", "list")
    r.run("env", "get")
    r.run("env", "health")

    for res in ("proxy", "sharedflow"):
        listing, rc = r.run(res, "list")
        for name in r.names(listing):
            r.run(res, "revisions", [name])
            r.run(res, "latest", [name])
            r.run(res, "deployed", [name])
            r.run(res, "deployed", [name, "--all-envs"])

    for scope in ("env", "org"):
        maps, rc = r.run("kvm", "list", ["--scope", scope])
        for m in r.names(maps):
            # `kvm get` prints entries (possibly secrets); only metadata is kept.
            r.run("kvm", "get", [m, "--scope", scope])

    ts, _ = r.run("target-server", "list")
    for t in r.names(ts):
        r.run("target-server", "get", [t])

    ks, _ = r.run("keystore", "list")
    for k in r.names(ks):
        r.run("keystore", "get", [k])
        r.run("truststore", "get", [k])
    r.run("truststore", "list")

    devs, _ = r.run("developer", "list")
    for d in r.names(devs):
        r.run("developer", "get", [d], mask=["developer"])

    prods, _ = r.run("product", "list")
    for p in r.names(prods):
        r.run("product", "get", [p])

    apps, _ = r.run("app", "list")
    r.run("app", "list", ["--expand"])
    for a in r.names(apps):
        r.run("app", "get", [a], mask=["app"])

    if edge:
        r.run("cache", "list")
        vh, _ = r.run("virtualhost", "list")
        for v in r.names(vh):
            r.run("virtualhost", "get", [v])
        r.run("user", "list")
        r.skip("envgroup", "list", [], "X/hybrid only")
    else:
        eg, _ = r.run("envgroup", "list")
        for g in r.names(eg):
            r.run("envgroup", "get", [g])
        for res in sorted(EDGE_ONLY):
            r.skip(res, "list", [], "Edge only")

    for res, verb in (("kvm", "export"), ("proxy", "download"), ("sharedflow", "download"),
                      ("env", "export")):
        if not args.write_files:
            r.skip(res, verb, [], "writes files (may contain secrets); pass --write-files DIR to run")

    written = write_files(args, r) if args.write_files else None

    xchecks = gcloud_crosscheck(args, r) if (args.gcloud and not edge) else []
    result = {
        "org": args.org, "env": args.env, "platform": args.platform, "sample": n,
        "started": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "rows": r.rows, "crosschecks": xchecks, "written": written,
        "show_credentials": bool(args.show_credentials),
    }
    return result


# --------------------------------------------------------------------------
# --write-files: the commands that write to disk
# --------------------------------------------------------------------------
def write_files(args, r):
    base = os.path.abspath(args.write_files)
    os.makedirs(base, mode=0o700, exist_ok=True)
    os.chmod(base, 0o700)
    long = args.timeout * 10

    def run(res, verb, argv, timeout=None):
        rc, out, err, ms, to = r.exec([res, verb] + argv, timeout=timeout or long)
        r.record(res, verb, argv, argv, rc, out, err, ms, to, note="writes files")
        return out

    run("kvm", "export", ["--scope", "env", "--out", os.path.join(base, "kvms-env")])
    run("kvm", "export", ["--scope", "org", "--out", os.path.join(base, "kvms-org")])
    for res in ("proxy", "sharedflow"):
        _rc, listing, _e, _ms, _to = r.exec([res, "list"])
        for name in r.names(listing):
            sub = "proxies" if res == "proxy" else "sharedflows"
            os.makedirs(os.path.join(base, sub), mode=0o700, exist_ok=True)
            run(res, "download", [name, "--latest", "-o", os.path.join(base, sub, name + ".zip")])
    extra = ["--show-credentials"] if args.show_credentials else []
    run("env", "export", [os.path.join(base, "env-export")] + extra)
    return summarize_dir(base)


def summarize_dir(base):
    files, total, loose = 0, 0, []
    for root, _dirs, names in os.walk(base):
        for n in names:
            path = os.path.join(root, n)
            st = os.stat(path)
            files += 1
            total += st.st_size
            if st.st_mode & 0o077:
                loose.append(os.path.relpath(path, base))
    top = {}
    for entry in sorted(os.listdir(base)):
        path = os.path.join(base, entry)
        count = sum(len(f) for _r, _d, f in os.walk(path)) if os.path.isdir(path) else 1
        top[entry] = count
    return {"dir": base, "files": files, "bytes": total, "by_folder": top, "loose_permissions": loose}


# --------------------------------------------------------------------------
# gcloud cross-check: compare counts, toolkit vs `gcloud apigee ... list`
# --------------------------------------------------------------------------
def count_lines(text):
    return len([l for l in text.splitlines() if l.strip()])


def gcloud_crosscheck(args, r):
    checks = [
        ("proxy list", ["proxy", "list"], ["apis", "list"], "value(name)"),
        ("env list", ["env", "list"], ["environments", "list"], "value(.)"),
        ("developer list", ["developer", "list"], ["developers", "list"], "value(email)"),
        ("product list", ["product", "list"], ["products", "list"], "value(name)"),
        ("app list", ["app", "list"], ["applications", "list"], "value(appId)"),
    ]
    out = []
    for label, tool_argv, g_argv, fmt in checks:
        rc, tool_out, _, _, _ = r.exec(tool_argv)
        gcmd = ["gcloud", "apigee"] + g_argv + ["--organization", args.org, "--format", fmt]
        try:
            p = subprocess.run(gcmd, capture_output=True, text=True, timeout=args.timeout,
                               stdin=subprocess.DEVNULL, env=r.env)
            g_rc, g_out = p.returncode, p.stdout
        except (OSError, subprocess.TimeoutExpired):
            g_rc, g_out = 1, ""
        entry = {"check": label, "gcloud": "gcloud apigee " + " ".join(g_argv),
                 "toolkit_count": count_lines(tool_out) if rc == 0 else None,
                 "gcloud_count": count_lines(g_out) if g_rc == 0 else None}
        t, g = entry["toolkit_count"], entry["gcloud_count"]
        entry["result"] = ("error" if t is None or g is None else "match" if t == g else "MISMATCH")
        out.append(entry)
    return out


# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
def fmt_legacy(names):
    if not names:
        return "(new)"
    shown = ", ".join("`%s`" % n for n in names[:3])
    return shown + (" +%d" % (len(names) - 3) if len(names) > 3 else "")


def render(result):
    rows = result["rows"]
    ran = [x for x in rows if x["status"] != "SKIP"]
    passed = [x for x in ran if x["status"] == "PASS"]
    failed = [x for x in ran if x["status"] == "FAIL"]
    skipped = [x for x in rows if x["status"] == "SKIP"]
    L = []
    L.append("# Live read-only sweep: %s / %s (%s)\n" % (result["org"], result.get("env") or "-", result["platform"]))
    L.append("Started %s, sampling up to %s names per resource.\n" % (result["started"], result["sample"]))
    L.append("## Summary\n")
    L.append("- %d commands run: **%d passed, %d failed**, %d skipped" % (len(ran), len(passed), len(failed), len(skipped)))
    total = sum(x["ms"] for x in ran)
    L.append("- total time %.1fs" % (total / 1000.0))
    L.append("")
    L.append("## Results (new command, legacy command it replaces)\n")
    L.append("| Result | New command | Legacy command | ms | lines | Note |")
    L.append("|---|---|---|---:|---:|---|")
    for x in rows:
        note = x["error"] or x["note"]
        L.append("| %s | `%s` | %s | %s | %s | %s |" % (
            x["status"], x["command"], fmt_legacy(x["legacy"]),
            x["ms"] if x["status"] != "SKIP" else "", x["lines"] if x["status"] != "SKIP" else "",
            note.replace("|", "/")))
    L.append("")
    L.append("## Analysis\n")
    if failed:
        L.append("### Failures by cause\n")
        groups = {}
        for x in failed:
            groups.setdefault(x["category"], []).append(x)
        advice = {
            "auth": "login problem: `gcloud auth login ACCOUNT --force` (or fix Edge credentials)",
            "permission": "403: the account lacks a role, or cannot see the org/project",
            "not_found": "404: the resource does not exist in this org/env",
            "rate_limited": "429: retry later or lower --sample",
            "server_error": "5xx: Apigee API error; retry, then check Google Cloud status",
            "timeout": "command exceeded the timeout (raise --timeout)",
            "unhealthy": "reported an unhealthy environment or deployment",
            "other": "see the error text in the table",
        }
        for cat, items in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            L.append("- **%s** (%d): %s" % (cat, len(items), advice.get(cat, "")))
            for x in items[:6]:
                L.append("  - `%s`: %s" % (x["command"], x["error"] or "exit %s" % x["exit"]))
            if len(items) > 6:
                L.append("  - ... and %d more" % (len(items) - 6))
        # one root cause is the usual story
        if len(groups) == 1 and len(failed) == len(ran):
            L.append("\nEvery command failed with the same cause, so this is a setup/auth problem, not a toolkit bug.")
        L.append("")
    else:
        L.append("No failures.\n")

    if passed:
        ms = [x["ms"] for x in passed]
        med = statistics.median(ms)
        cutoff = max(3000, 3 * med)
        slow = sorted([x for x in passed if x["ms"] >= cutoff], key=lambda x: -x["ms"])
        L.append("### Timing\n")
        L.append("- median %.0f ms, slowest %d ms" % (med, max(ms)))
        for x in slow[:8]:
            L.append("- slow: `%s` took %d ms (threshold %d ms)" % (x["command"], x["ms"], cutoff))
        L.append("")
        empty = [x for x in passed if x["verb"] in ("list",) and x["lines"] == 0]
        if empty:
            L.append("### Empty results (succeeded but returned nothing)\n")
            for x in empty:
                L.append("- `%s`" % x["command"])
            L.append("")

    if result.get("crosschecks"):
        L.append("### Cross-check against gcloud\n")
        L.append("| Check | gcloud command | toolkit | gcloud | Result |")
        L.append("|---|---|---:|---:|---|")
        for c in result["crosschecks"]:
            L.append("| %s | `%s` | %s | %s | %s |" % (
                c["check"], c["gcloud"], c["toolkit_count"], c["gcloud_count"], c["result"]))
        bad = [c for c in result["crosschecks"] if c["result"] != "match"]
        L.append("")
        L.append("All counts agree." if not bad else
                 "%d cross-check(s) disagree or errored: investigate paging, filters or permissions." % len(bad))
        L.append("")

    w = result.get("written")
    if w:
        L.append("### Files written (--write-files)\n")
        L.append("Directory `%s`: %d files, %d bytes. Contents are not shown here." % (w["dir"], w["files"], w["bytes"]))
        for folder, count in w["by_folder"].items():
            L.append("- `%s`: %d file(s)" % (folder, count))
        if w["loose_permissions"]:
            L.append("- WARNING: %d file(s) readable by group/others, e.g. `%s`" % (
                len(w["loose_permissions"]), w["loose_permissions"][0]))
        else:
            L.append("- all files are private to your user (no group/other access)")
        L.append("- these files may hold secrets (KVM values%s): do not commit or share them" % (
            ", app keys and secrets" if result.get("show_credentials") else ""))
        L.append("")

    new_cmds = sorted({x["command"] for x in ran if not x["legacy"]})
    if new_cmds:
        L.append("### Commands with no legacy equivalent in INVENTORY.md\n")
        for c in new_cmds:
            L.append("- `%s`" % c)
        L.append("")
    return "\n".join(L) + "\n"


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("run", "report"):
        p = sub.add_parser(name)
        p.add_argument("--out", default=os.path.join(ROOT, "tests", "live_all"))
        if name == "run":
            p.add_argument("--org", default=os.environ.get("APIGEE_ORG", "corp-apigee"))
            p.add_argument("--env", default=os.environ.get("APIGEE_ENV", "dev"))
            p.add_argument("--platform", default=os.environ.get("APIGEE_PLATFORM", "x"))
            p.add_argument("--sample", type=int, default=2, help="names to query per resource (default 2)")
            p.add_argument("--timeout", type=int, default=60)
            p.add_argument("--gcloud", action="store_true", help="cross-check counts with gcloud apigee ... list (X only)")
            p.add_argument("--write-files", metavar="DIR", help="also run the commands that write files (kvm export, proxy/sharedflow download, env export) into DIR")
            p.add_argument("--show-credentials", action="store_true", help="with --write-files: include app consumer keys and secrets in the env export")
            p.add_argument("--no-redact", action="store_true", help="show developer emails and app ids")
    args = ap.parse_args()
    os.makedirs(args.out, mode=0o700, exist_ok=True)
    res_path = os.path.join(args.out, "results.json")
    if args.cmd == "run":
        result = sweep(args)
        fd = os.open(res_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            json.dump(result, f, indent=2)
    else:
        result = json.load(open(res_path))
        legacy = load_legacy_map()
        for x in result["rows"]:
            x["legacy"] = legacy_for(legacy, x["resource"], x["verb"])
    report = render(result)
    rp = os.path.join(args.out, "report.md")
    fd = os.open(rp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(report)
    sys.stdout.write(report)
    sys.stdout.write("\nSaved: %s and %s\n" % (res_path, rp))
    failed = [x for x in result["rows"] if x["status"] == "FAIL"]
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
