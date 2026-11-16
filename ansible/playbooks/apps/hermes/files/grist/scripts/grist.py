#!/usr/bin/env python3
"""Read and change rows in the user's Grist documents, through Grist's API.

Prints short JSON. Run with no command for the list. It adds rows and changes
single rows; it has no way to delete anything, or to change a table's columns.
Values are checked against each column's type before anything is sent.
"""
import datetime
import getpass
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

HOME = os.environ.get("HERMES_HOME", "/opt/data")


def setting(name):
    """From the environment, or Hermes's .env when run by hand (docker exec)."""
    if os.environ.get(name):
        return os.environ[name]
    try:
        with open(os.path.join(HOME, ".env")) as fh:
            for line in fh:
                if line.startswith(name + "="):
                    return line.split("=", 1)[1].strip()
    except OSError:
        pass
    return ""


URL = setting("GRIST_URL").rstrip("/")
TOKEN_FILE = os.path.join(HOME, "data", "grist", "token")
ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MAX_ROWS = 200


class Stop(Exception):
    """A problem to report to the user as it is."""


def token():
    try:
        with open(TOKEN_FILE) as fh:
            return fh.read().strip()
    except FileNotFoundError:
        raise Stop("No Grist API key yet. The user must run the set-token command (see the docs).")


def api(method, path, body=None, query=None):
    if not URL:
        raise Stop("GRIST_URL is not set.")
    target = f"{URL}/api{path}"
    if query:
        target += "?" + urllib.parse.urlencode(query)
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(target, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as err:
        try:
            detail = str(json.loads(err.read()).get("error", ""))[:200]
        except (ValueError, AttributeError):
            detail = ""
        if err.code == 401:
            raise Stop("Grist refused the key (wrong, removed or replaced). "
                       "The user must make a new one and run set-token.")
        if err.code == 403:
            raise Stop(f"Grist refused access, so nothing was changed. {detail}".strip())
        if err.code == 404:
            raise Stop(f"Not found in Grist. {detail}".strip())
        raise Stop(f"Grist answered {err.code}, so nothing was changed. {detail}".strip())
    except urllib.error.URLError as err:
        raise Stop(f"Could not reach Grist at {URL}: {err.reason}")


def from_json(text, what):
    try:
        return json.loads(text)
    except ValueError as err:
        raise Stop(f"{what} must be valid JSON: {err}")


# --- Finding documents, tables and columns ---

def all_docs():
    docs = []
    for space in api("GET", "/orgs/current/workspaces") or []:
        for doc in space.get("docs", []):
            docs.append({"name": doc["name"], "id": doc["id"], "workspace": space["name"]})
    return docs


def find_doc(name):
    docs = all_docs()
    hits = [d for d in docs if d["id"] == name] or [d for d in docs if d["name"].lower() == name.lower()]
    if len(hits) == 1:
        return hits[0]
    if not hits:
        raise Stop(f"No document named {name!r}. Documents: {[d['name'] for d in docs]}")
    raise Stop(f"{len(hits)} documents are named {name!r}. Use the id: {[d['id'] for d in hits]}")


def table_ids(doc):
    return [t["id"] for t in api("GET", f"/docs/{doc}/tables")["tables"]]


def find_table(doc, name):
    ids = table_ids(doc)
    hits = [t for t in ids if t == name] or [t for t in ids if t.lower() == name.lower()]
    if len(hits) != 1:
        raise Stop(f"No table named {name!r}. Tables: {ids}")
    return hits[0]


def columns(doc, table):
    """Column id -> label, type, whether Grist calculates it, and its choices."""
    cols = {}
    for col in api("GET", f"/docs/{doc}/tables/{table}/columns")["columns"]:
        fields = col["fields"]
        try:
            options = json.loads(fields.get("widgetOptions") or "{}")
        except ValueError:
            options = {}
        cols[col["id"]] = {
            "label": fields.get("label") or col["id"],
            "type": fields.get("type") or "Any",
            # A filled-in formula on a formula column. A data column may hold a
            # formula too (a default for new rows): that one can be written.
            "formula": bool(fields.get("isFormula") and (fields.get("formula") or "").strip()),
            "choices": options.get("choices") or [],
        }
    return cols


# --- Values: JSON from the command line <-> what Grist stores ---

def to_grist(name, col, value):
    """Check one value against its column and give it Grist's form."""
    kind = col["type"].split(":")[0]
    if value is None:
        return None

    def wrong(expected):
        return Stop(f"Column {name} is {col['type']}: give {expected}, not {json.dumps(value)}. "
                    "Nothing was changed.")

    if kind == "Date":
        if not (isinstance(value, str) and ISO_DATE.match(value)):
            raise wrong('a date like "2026-11-12"')
        try:
            day = datetime.date.fromisoformat(value)
        except ValueError:
            raise wrong("a real date")
        return (day - datetime.date(1970, 1, 1)).days * 86400
    if kind == "DateTime":
        try:
            moment = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except (AttributeError, ValueError):
            moment = None
        if moment is None or moment.tzinfo is None:
            raise wrong('a time with its offset, like "2026-11-12T18:30:00+00:00"')
        return moment.timestamp()
    if kind in ("Numeric", "Int"):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise wrong("a JSON number")
        if kind == "Int" and int(value) != value:
            raise wrong("a whole number")
        return value
    if kind == "Bool":
        if not isinstance(value, bool):
            raise wrong("true or false")
        return value
    if kind == "Text":
        if not isinstance(value, str):
            raise wrong("a string")
        return value
    if kind == "Choice":
        if not isinstance(value, str) or (value and col["choices"] and value not in col["choices"]):
            raise wrong(f"one of {col['choices']}")
        return value
    if kind == "ChoiceList":
        if not isinstance(value, list) or any(v not in col["choices"] for v in value if col["choices"]):
            raise wrong(f"a list taken from {col['choices']}")
        return ["L", *value]
    if kind == "Ref":
        if isinstance(value, bool) or not isinstance(value, int):
            raise wrong(f"the id of a row in {col['type'][4:]}")
        return value
    if kind == "RefList":
        if not isinstance(value, list) or any(isinstance(v, bool) or not isinstance(v, int) for v in value):
            raise wrong(f"a list of row ids in {col['type'][8:]}")
        return ["L", *value]
    if isinstance(value, (list, dict)):
        raise wrong("a plain value")
    return value


def to_date(seconds):
    return (datetime.datetime(1970, 1, 1) + datetime.timedelta(seconds=seconds)).date().isoformat()


def to_time(seconds):
    return (datetime.datetime(1970, 1, 1) + datetime.timedelta(seconds=seconds)).isoformat() + "Z"


def from_grist(col, value):
    """Give one stored value a readable form."""
    number = isinstance(value, (int, float)) and not isinstance(value, bool)
    if isinstance(value, list) and value:
        code, rest = value[0], value[1:]
        if code == "L":
            return rest
        if code == "d" and rest:
            return to_date(rest[0])
        if code == "D" and rest:
            return to_time(rest[0])
        if code == "E":
            return "#ERROR " + " ".join(str(part) for part in rest[:2])
        return value
    kind = (col or {}).get("type", "Any").split(":")[0]
    if kind == "Date" and number:
        return to_date(value)
    if kind == "DateTime" and number:
        return to_time(value)
    return value


def to_fields(cols, given):
    """Check a row's fields and turn them into Grist's form."""
    if not isinstance(given, dict) or not given:
        raise Stop('A row is a JSON object of column ids, e.g. {"Date": "2026-11-12", "Amount": -54.2}')
    fields = {}
    for name, value in given.items():
        if name not in cols:
            raise Stop(f"No column with the id {name!r}. Columns: {list(cols)}. Nothing was changed.")
        if cols[name]["formula"]:
            raise Stop(f"Column {name} is calculated by Grist and can't be written. Nothing was changed.")
        fields[name] = to_grist(name, cols[name], value)
    return fields


def rows_of(cols, records):
    return [{"id": r["id"], "fields": {k: from_grist(cols.get(k), v) for k, v in r["fields"].items()}}
            for r in records]


def fetch(doc, table, cols, ids):
    query = {"filter": json.dumps({"id": ids})}
    found = {r["id"]: r for r in api("GET", f"/docs/{doc}/tables/{table}/records", query=query)["records"]}
    return rows_of(cols, [found[i] for i in ids if i in found])


# --- Commands ---

def cmd_docs():
    return {"documents": all_docs()}


def cmd_tables(doc_name):
    doc = find_doc(doc_name)
    tables = []
    for table in table_ids(doc["id"]):
        shown = []
        for name, col in columns(doc["id"], table).items():
            entry = {"id": name, "type": col["type"]}
            if col["label"] != name:
                entry["label"] = col["label"]
            if col["formula"]:
                entry["calculated"] = True
            if col["choices"]:
                entry["choices"] = col["choices"]
            shown.append(entry)
        tables.append({"table": table, "columns": shown})
    return {"document": doc["name"], "tables": tables}


def cmd_read(doc_name, table_name, last="20"):
    """The rows added most recently, oldest of them first."""
    try:
        count = max(1, min(int(last), 500))
    except ValueError:
        raise Stop("The number of rows must be a whole number.")
    doc = find_doc(doc_name)
    table = find_table(doc["id"], table_name)
    cols = columns(doc["id"], table)
    query = {"sort": "-id", "limit": count}
    records = api("GET", f"/docs/{doc['id']}/tables/{table}/records", query=query)["records"]
    return {"document": doc["name"], "table": table, "rows": rows_of(cols, reversed(records))}


def cmd_add(doc_name, table_name, rows_json):
    rows = from_json(rows_json, "Rows")
    if not isinstance(rows, list) or not rows or len(rows) > MAX_ROWS:
        raise Stop(f'Rows must be a JSON list of 1 to {MAX_ROWS} objects, e.g. [{{"Date": "2026-11-12", "Amount": -54.2}}]')
    doc = find_doc(doc_name)
    table = find_table(doc["id"], table_name)
    cols = columns(doc["id"], table)
    records = [{"fields": to_fields(cols, row)} for row in rows]
    made = api("POST", f"/docs/{doc['id']}/tables/{table}/records", {"records": records})["records"]
    return {"document": doc["name"], "table": table,
            "added": fetch(doc["id"], table, cols, [r["id"] for r in made])}


def cmd_set(doc_name, table_name, row_id, fields_json):
    try:
        row = int(row_id)
    except ValueError:
        raise Stop("The row is its id, a whole number, as `read` shows it.")
    doc = find_doc(doc_name)
    table = find_table(doc["id"], table_name)
    cols = columns(doc["id"], table)
    given = from_json(fields_json, "The changes")
    fields = to_fields(cols, given)
    before = fetch(doc["id"], table, cols, [row])
    if not before:
        raise Stop(f"No row with the id {row} in {table}. Nothing was changed.")
    api("PATCH", f"/docs/{doc['id']}/tables/{table}/records", {"records": [{"id": row, "fields": fields}]})
    return {"document": doc["name"], "table": table,
            "was": {name: before[0]["fields"].get(name) for name in given},
            "now": fetch(doc["id"], table, cols, [row])[0]}


def cmd_set_token():
    value = getpass.getpass("Grist API key (hidden): ").strip()
    if not value:
        raise Stop("Nothing entered; the key was not changed.")
    os.makedirs(os.path.dirname(TOKEN_FILE), mode=0o700, exist_ok=True)
    fd = os.open(TOKEN_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        fh.write(value + "\n")
    return {"key": "saved", "documents": len(all_docs())}


COMMANDS = {
    "docs": (cmd_docs, "", "list the documents"),
    "tables": (cmd_tables, "<document>", "a document's tables and their columns"),
    "read": (cmd_read, "<document> <table> [last-n-rows]", "the rows added most recently (default 20)"),
    "add": (cmd_add, "<document> <table> '<json list of rows>'", "add rows"),
    "set": (cmd_set, "<document> <table> <row-id> '<json fields>'", "change fields of one row"),
    "set-token": (cmd_set_token, "", "store the Grist API key (asks at a hidden prompt)"),
}


def main():
    args = sys.argv[1:]
    if not args or args[0] not in COMMANDS:
        print("\n".join(f"{name} {usage}\n    {text}" for name, (_, usage, text) in COMMANDS.items()))
        return 0 if not args else 2
    try:
        print(json.dumps(COMMANDS[args[0]][0](*args[1:]), ensure_ascii=False))
    except Stop as stop:
        print(json.dumps({"error": str(stop)}, ensure_ascii=False))
        return 1
    except TypeError:
        print(json.dumps({"error": f"Usage: {args[0]} {COMMANDS[args[0]][1]}"}))
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
