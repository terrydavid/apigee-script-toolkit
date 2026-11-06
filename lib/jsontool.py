#!/usr/bin/env python3
"""python3 fallback for lib/json.sh when jq is not installed.

Each operation mirrors the jq program of the same name in lib/json.sh and
must produce byte-identical output.
"""

import json
import re
import sys


def dump(obj):
    return json.dumps(obj, separators=(",", ":"), ensure_ascii=False)


def text(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (dict, list)):
        return dump(value)
    return str(value)


def load_stdin():
    data = sys.stdin.read()
    return json.loads(data) if data.strip() else None


def load_stream():
    decoder = json.JSONDecoder()
    data = sys.stdin.read()
    pos, items = 0, []
    while True:
        while pos < len(data) and data[pos].isspace():
            pos += 1
        if pos >= len(data):
            return items
        obj, pos = decoder.raw_decode(data, pos)
        items.append(obj)


def name_of(item):
    if isinstance(item, dict):
        for key in ("name", "email", "appId", "aliasName", "id"):
            if item.get(key) is not None:
                return text(item[key])
        return None
    return text(item)


def emit_names(items):
    for item in items or []:
        name = name_of(item)
        if name is not None:
            print(name)


def op_names(args):
    doc = load_stdin()
    if args:
        emit_names((doc or {}).get(args[0]) or [])
    elif isinstance(doc, list):
        emit_names(doc)
    elif isinstance(doc, dict):
        arrays = [v for v in doc.values() if isinstance(v, list)]
        emit_names(arrays[0] if arrays else [])


def lookup(cur, path):
    for part in path.split("."):
        if isinstance(cur, dict):
            cur = cur.get(part)
        elif isinstance(cur, list) and re.fullmatch(r"\d+", part):
            idx = int(part)
            cur = cur[idx] if idx < len(cur) else None
        else:
            cur = None
    return cur


def op_get(args):
    cur = lookup(load_stdin(), args[0])
    if cur is not None:
        print(text(cur))


def op_get_raw(args):
    cur = lookup(load_stdin(), args[0])
    if cur is not None:
        sys.stdout.write(text(cur))


def deep_merge(base, override):
    if isinstance(base, dict) and isinstance(override, dict):
        out = dict(base)
        for key, value in override.items():
            out[key] = deep_merge(base[key], value) if key in base else value
        return out
    return override


def op_merge(args):
    print(json.dumps(deep_merge(load_stdin(), json.loads(args[0])), indent=2, ensure_ascii=False))


def op_build(args):
    out = {}
    for arg in args:
        match = re.match(r"^([^:=]+)(:?=)(.*)$", arg, re.S)
        if not match:
            raise SystemExit("build: bad argument")
        key, kind, value = match.groups()
        out[key] = json.loads(value) if kind == ":=" else value
    print(json.dumps(out, indent=2, ensure_ascii=False))


def op_deployed_revs(_args):
    doc = load_stdin() or {}
    for rev in doc.get("revision") or []:
        print(text(rev.get("name")))
    for dep in doc.get("deployments") or []:
        print(text(dep.get("revision")))


def op_deployed_all(_args):
    doc = load_stdin() or {}
    for env in doc.get("environment") or []:
        for rev in env.get("revision") or []:
            print("%s %s" % (text(env.get("name")), text(rev.get("name"))))
    for dep in doc.get("deployments") or []:
        print("%s %s" % (text(dep.get("environment")), text(dep.get("revision"))))


def op_env_deployments(_args):
    doc = load_stdin() or {}
    for proxy in doc.get("aPIProxy") or []:
        for rev in proxy.get("revision") or []:
            print("%s %s %s" % (text(proxy.get("name")), text(rev.get("name")), text(rev.get("state") or "unknown")))
    for dep in doc.get("deployments") or []:
        name = dep.get("apiProxy") or dep.get("sharedFlow") or "?"
        print("%s %s %s" % (text(name), text(dep.get("revision")), text(dep.get("state") or "deployed")))


def op_kvm_entries(_args):
    doc = load_stdin() or {}
    entries = doc.get("entries") or doc.get("entry") or doc.get("keyValueEntries") or []
    for entry in entries:
        print(dump({"name": entry.get("name"), "value": entry.get("value")}))


def op_kvm_doc(args):
    encrypted = json.loads(args[1]) if len(args) > 1 else True
    doc = {"name": args[0], "encrypted": encrypted, "entries": load_stream()}
    print(json.dumps(doc, indent=2, ensure_ascii=False))


def op_kvm_entry(args):
    print(dump({"name": args[0], "value": sys.stdin.read()}))


def op_entries_to_lines(_args):
    for entry in load_stream():
        print("%s;%s" % (text(entry.get("name")), text(entry.get("value"))))


def op_masked_keys(_args):
    for entry in load_stream():
        value = entry.get("value")
        if isinstance(value, str) and re.fullmatch(r"\*+", value):
            print(text(entry.get("name")))


def ascii_lower(value):
    return "".join(chr(ord(c) + 32) if "A" <= c <= "Z" else c for c in value)


def op_app_statuses(_args):
    doc = load_stdin()
    apps = doc.get("app") if isinstance(doc, dict) else doc
    for app in apps or []:
        if not isinstance(app, dict):
            continue
        status = app.get("status")
        status = ascii_lower(status) if isinstance(status, str) and status else "-"
        name = app.get("name")
        print("%s %s" % (status, "null" if name is None else text(name)))


def op_pretty(_args):
    print(json.dumps(load_stdin(), indent=2, ensure_ascii=False))


OPS = {
    "pretty": op_pretty,
    "names": op_names,
    "get": op_get,
    "get-raw": op_get_raw,
    "merge": op_merge,
    "build": op_build,
    "deployed-revs": op_deployed_revs,
    "deployed-all": op_deployed_all,
    "env-deployments": op_env_deployments,
    "kvm-entries": op_kvm_entries,
    "kvm-doc": op_kvm_doc,
    "kvm-entry": op_kvm_entry,
    "entries-to-lines": op_entries_to_lines,
    "masked-keys": op_masked_keys,
    "app-statuses": op_app_statuses,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in OPS:
        sys.stderr.write("jsontool.py: unknown op\n")
        return 2
    OPS[sys.argv[1]](sys.argv[2:])
    return 0


if __name__ == "__main__":
    sys.exit(main())
