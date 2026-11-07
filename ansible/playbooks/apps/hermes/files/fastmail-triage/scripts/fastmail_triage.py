#!/usr/bin/env python3
"""fastmail_triage: sort a Fastmail Inbox once a week, with the model kept away from the mail API.

Commands
  scan --cron             Hermes job only: read the Inbox, set protected mail aside, print a digest for a model with no tools
  apply [--cron]          check the model's decisions against the scan, move mail, print the report
  undo [--run ID]         move the mail from a run back to the Inbox
  report                  print the last report
  check                   verify the token, the folders, the Hermes jobs and the mode
  mode [propose|apply]    show or set the mode (propose never moves anything)
  teach SENDER CATEGORY   always send SENDER (an address or a domain) to CATEGORY, or to Stay
  set-token               store the Fastmail token, read from a hidden prompt or from stdin

Guardrails live in this file, not in the model's instructions. It only moves mail out of the Inbox into the folders
in the config. It never deletes, trashes or sends. Nothing written by a stranger other than a checked sender address
reaches the report, because Hermes acts on tags in delivered text and the report may be read by a model with tools.
Python stdlib only.
"""
from __future__ import annotations

import argparse
import collections
import getpass
import http.client
import json
import os
import re
import secrets
import shutil
import sqlite3
import stat
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

SESSION_URL = "https://api.fastmail.com/jmap/session"
USING = ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"]
MAIL_CAPABILITY = "urn:ietf:params:jmap:mail"
DECIDE_JOB = "fastmail-triage-decide"
APPLY_JOB = "fastmail-triage-apply"
STAY = "Stay"
PROPS = [
    "id", "threadId", "receivedAt", "from", "subject", "keywords", "mailboxIds",
    "header:X-Delivered-To:asRaw:all", "header:X-ME-VSCategory:asRaw:all",
    "header:X-Spam-known-sender:asRaw:all", "header:List-Unsubscribe:asRaw",
    "header:List-Id:asRaw", "header:In-Reply-To:asRaw", "header:Auto-Submitted:asRaw",
]
HANDS_OFF_KEYWORDS = ("$flagged", "$notify", "$followed", "$answered", "$draft", "$phishing")
ALARM_TAGS = ("phishing", "spam", "bounce")
DIGEST_HEADER = "FASTMAIL DIGEST run"
UNION_LISTS = ("own_domains", "own_addresses", "freemail_domains", "protected_aliases", "protected_domains",
               "protected_strong_phrases", "protected_soft_phrases", "public_suffixes")
ROBOT_LOCALPART = re.compile(
    r"^(?:no[-_.]?reply|do[-_.]?not[-_.]?reply|notification|notify|alert|mailer|automated|auto-confirm)", re.I)
BOUNCE_LOCALPART = re.compile(r"^(?:mailer-daemon|postmaster)$", re.I)
REPLY_SUBJECT = re.compile(r"^\s*(?:re|aw|sv|wg|fw|fwd)\s*:", re.I)
TAG_SHAPE = re.compile(r"[a-z]+(?::[a-z_-]+)?")
SAFE_ADDRESS = re.compile(r"[a-z0-9._%+\-]{1,40}@[a-z0-9.\-]{1,40}\.[a-z]{2,12}")
MIXED_SCRIPT = re.compile(r"[a-zA-Z][Ѐ-ӿͰ-Ͽ]|[Ѐ-ӿͰ-Ͽ][a-zA-Z]")
# Hermes refuses a cron job whose assembled prompt matches its first four patterns, so a hostile subject could
# otherwise stop the agent step. The rest are the same scanner's stricter list plus text aimed at a model.
INJECTION_PATTERNS = [re.compile(p, re.I | re.M) for p in (
    r"ignore\s+(?:\w+\s+)*(?:previous|all|above|prior)\s+(?:\w+\s+)*instructions",
    r"do\s+not\s+tell\s+the\s+user",
    r"system\s+prompt\s+override",
    r"disregard\s+(?:your|all|any)\s+(?:instructions|rules|guidelines)",
    r"cat\s+[^\n]*(?:\.env|credentials|\.netrc|\.pgpass|id_rsa|id_ed25519|id_ecdsa)",
    r"authorized_keys",
    r"/etc/sudoers|visudo",
    r"rm\s+-rf\s+/",
    r"\b(?:new|updated|previous|prior|hidden)\s+instructions\b",
    r"\bsystem\s+prompt\b",
    r"\byou\s+are\s+(?:now\s+)?(?:an?\s+)?(?:ai|assistant|agent|llm|language\s+model)\b",
    r"^\s*(?:system|assistant|developer)\s*:\s",
    r"</?\s*(?:system|assistant|instructions?|tool|tool_call|function_call)\b",
    r"\[\s*(?:system|inst|assistant)\b",
    r"\b(?:tool|function)[_ ]calls?\b",
    r"\bwakeAgent\b|\brun_id\b|\bfastmail_triage\b|\bFASTMAIL_API_TOKEN\b",
    r"\"(?:category|decisions|look)\"\s*:",
    r"\bMEDIA\s*:",
)]


class TriageError(Exception):
    """A failure to report to the user. Its text never contains the token or text from a message."""


# ---------------------------------------------------------------- paths, config, state
def hermes_home() -> Path:
    return Path(os.environ.get("HERMES_HOME") or Path.home() / ".hermes").expanduser()


def data_dir() -> Path:
    path = hermes_home() / "data" / "fastmail-triage"
    (path / "runs").mkdir(parents=True, exist_ok=True)
    os.chmod(path, 0o700)
    return path


def write_private(path: Path, text: str) -> None:
    tmp = path.with_name(path.name + ".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(text)
    os.replace(tmp, path)


def read_json(path: Path, fallback):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return fallback


def user_config() -> dict:
    data = read_json(data_dir() / "config.json", {"mode": "propose", "taught": {}})
    return data if isinstance(data, dict) else {"mode": "propose", "taught": {}}


def load_config() -> dict:
    """Skill defaults, then site-config.json (who you are, written at deploy time), then config.json (what this tool saves).

    The protected lists only grow, so skill updates always reach an install.
    """
    defaults = json.loads((Path(__file__).resolve().parent.parent / "references" / "default-config.json")
                          .read_text(encoding="utf-8"))
    site = read_json(data_dir() / "site-config.json", {})
    site = site if isinstance(site, dict) else {}
    mine = user_config()
    merged = {**defaults, **site, **mine}
    for key in UNION_LISTS:
        merged[key] = sorted(set(defaults.get(key, [])) | set(site.get(key, [])) | set(mine.get(key, [])))
    return merged


def identity_problem(cfg: dict) -> str | None:
    """Without these, your own mail looks like a stranger's and the private protections are missing, so nothing runs."""
    if cfg.get("catchall_domain") and cfg.get("own_domains"):
        return None
    return f"catchall_domain and own_domains are not set in {data_dir() / 'site-config.json'}"


def save_user_config(mine: dict) -> None:
    write_private(data_dir() / "config.json", json.dumps(mine, indent=2) + "\n")


def load_state() -> dict:
    state = read_json(data_dir() / "state.json", {})
    return {"settled": state.get("settled", {}) if isinstance(state, dict) else {}}


def save_state(state: dict) -> None:
    write_private(data_dir() / "state.json", json.dumps(state))


def load_token() -> str:
    path = data_dir() / "token"
    token = path.read_text(encoding="utf-8").strip() if path.exists() else ""
    token = token or os.environ.get("FASTMAIL_API_TOKEN", "").strip()
    if not token:
        raise TriageError("No Fastmail token yet. Run: fastmail_triage.py set-token")
    return token


# ---------------------------------------------------------------- JMAP client
class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):  # never carry the Authorization header to another URL
        return None


class Jmap:
    def __init__(self, token: str, opener=None):
        self._token = token
        self._opener = opener or urllib.request.build_opener(_NoRedirect)
        self.session = self._http(SESSION_URL)
        api = urllib.parse.urlparse(str(self.session.get("apiUrl", "")))
        host = api.hostname or ""
        if api.scheme != "https" or not host.endswith(".fastmail.com") or re.search(r"[^a-z0-9.\-]", host):
            raise TriageError("The session's API address is not on fastmail.com, so the token was not sent there.")
        self.account = (self.session.get("primaryAccounts") or {}).get(MAIL_CAPABILITY)
        if not self.account:
            raise TriageError("The token has no mail access. Create it with type JMAP and the Email scope.")
        core = (self.session.get("capabilities") or {}).get("urn:ietf:params:jmap:core") or {}
        self.max_get = max(1, min(int(core.get("maxObjectsInGet", 200)), 200))
        self.max_set = max(1, min(int(core.get("maxObjectsInSet", 100)), 100))

    def _http(self, url: str, body: bytes | None = None) -> dict:
        request = urllib.request.Request(url, data=body, method="POST" if body else "GET", headers={
            "Authorization": f"Bearer {self._token}", "Content-Type": "application/json",
            "User-Agent": "hermes-fastmail-triage/2.0"})
        for attempt in range(4):
            delay = 2 ** attempt * 2
            try:
                with self._opener.open(request, timeout=60) as response:
                    return json.loads(response.read().decode("utf-8"))
            except urllib.error.HTTPError as exc:
                if exc.code in (401, 403):
                    raise TriageError(f"Fastmail refused the token (HTTP {exc.code}). Check it and its scope.") from None
                if exc.code not in (429, 500, 502, 503, 504) or attempt == 3:
                    raise TriageError(f"Fastmail returned HTTP {exc.code}.") from None
                retry_after = exc.headers.get("Retry-After") if exc.headers else None
                delay = int(retry_after) if str(retry_after or "").isdigit() else delay
            except (OSError, http.client.HTTPException, ValueError) as exc:
                if attempt == 3:
                    raise TriageError(f"Could not reach Fastmail ({type(exc).__name__}).") from None
            time.sleep(min(delay, 30))
        raise TriageError("Could not reach Fastmail.")

    def method(self, name: str, args: dict) -> dict:
        payload = {"using": USING, "methodCalls": [[name, {"accountId": self.account, **args}, "0"]]}
        responses = self._http(self.session["apiUrl"], json.dumps(payload).encode("utf-8")).get("methodResponses") or []
        if not responses:
            raise TriageError(f"{name} returned nothing.")
        if responses[0][0] == "error":
            raise TriageError(f"{name} failed: {clean_text(responses[0][1].get('type'), 40) or 'unknown error'}.")
        return responses[0][1]


def connect() -> Jmap:
    return Jmap(load_token())


def get_all(jm, name: str, ids: list, properties: list | None = None) -> list:
    found, step = [], getattr(jm, "max_get", 200)
    for start in range(0, len(ids), step):
        args = {"ids": ids[start:start + step]}
        if properties:
            args["properties"] = properties
        found.extend(jm.method(name, args).get("list", []))
    return found


def query_ids(jm, flt: dict, cap: int) -> list:
    ids: list = []
    while len(ids) < cap:  # a server may return fewer than asked, so only an empty page ends the list
        page = jm.method("Email/query", {
            "filter": flt, "sort": [{"property": "receivedAt", "isAscending": False}],
            "position": len(ids), "limit": min(500, cap - len(ids))}).get("ids", [])
        if not page:
            break
        ids.extend(page)
    return ids


def mailboxes(jm) -> dict:
    boxes = jm.method("Mailbox/get", {"ids": None, "properties": ["id", "name", "parentId", "role"]}).get("list", [])
    by_role = {b["role"]: b["id"] for b in boxes if b.get("role")}
    by_name = {b["name"]: b["id"] for b in boxes if not b.get("parentId")}
    if "inbox" not in by_role:
        raise TriageError("Fastmail reported no Inbox.")
    return {"role": by_role, "name": by_name}


# ---------------------------------------------------------------- reading a message
def clean_text(value, limit: int = 80) -> str:
    text = unicodedata.normalize("NFKC", str(value or "")[:4000])
    text = "".join(" " if ch in "\t\r\n" else ("" if unicodedata.category(ch).startswith("C") else ch) for ch in text)
    text = re.sub(r"\s+", " ", text.replace("`", "'")).strip()
    return text if len(text) <= limit else text[:limit - 1].rstrip() + "…"


def looks_like_injection(text: str) -> bool:
    return any(p.search(text) for p in INJECTION_PATTERNS)


def as_list(value) -> list:
    # A sender can repeat a header thousands of times. Fastmail's own copies come first, so keep only the first few.
    return [str(v)[:300] for v in value[:10]] if isinstance(value, list) else ([str(value)[:300]] if value else [])


def phrase_regex(phrases) -> re.Pattern:
    parts = []
    for phrase in phrases:
        body = re.escape(phrase.lower())
        parts.append(("(?<![a-z0-9])" if phrase[0].isalnum() else "") + body + ("(?![a-z0-9])" if phrase[-1].isalnum() else ""))
    return re.compile("|".join(parts) or r"(?!x)x")


def normalize(email: dict, cfg: dict) -> dict:
    sender = (email.get("from") or [{}])[0] or {}
    address = clean_text(sender.get("email"), 120).lower()
    catchall = re.escape(cfg["catchall_domain"])
    aliases = []
    for value in as_list(email.get("header:X-Delivered-To:asRaw:all")):
        match = re.search(rf"([^<\s,;@]+)@{catchall}", value, re.I)
        if match:
            aliases.append(re.sub(r"[^a-z0-9._+\-]", "", match.group(1).lower())[:40])
    # A sender can add its own copy of this header. Any alarming copy wins, and Fastmail's own copy comes first.
    tags = [clean_text(t, 40).lower() for t in as_list(email.get("header:X-ME-VSCategory:asRaw:all"))]
    tag = next((t for t in tags if t.startswith(ALARM_TAGS)), "")
    tag = tag or next((t for t in tags if TAG_SHAPE.fullmatch(t)), "")
    name, subject = clean_text(sender.get("name"), 300), clean_text(email.get("subject"), 300)
    return {
        "id": email["id"], "thread": email.get("threadId"), "address": address,
        "domain": address.rpartition("@")[2], "localpart": address.partition("@")[0],
        "name": name[:40], "subject": subject[:79] + ("…" if len(subject) > 79 else ""),
        "fields": (name, subject, address, " ".join(aliases)[:300]), "subject_match": subject.replace("’", "'").lower(),
        "aliases": aliases, "tag": tag, "keywords": email.get("keywords") or {}, "received": email.get("receivedAt") or "",
        "known": any(v.strip().lower().startswith("yes") for v in as_list(email.get("header:X-Spam-known-sender:asRaw:all"))[:1]),
        "list": bool(str(email.get("header:List-Unsubscribe:asRaw") or "").strip() or str(email.get("header:List-Id:asRaw") or "").strip()),
        "reply": bool(str(email.get("header:In-Reply-To:asRaw") or "").strip()),
        "auto": str(email.get("header:Auto-Submitted:asRaw") or "").strip().lower().startswith("auto-generated"),
    }


def domain_matches(domain: str, listed) -> bool:
    return any(domain == d or domain.endswith("." + d) for d in listed)


def taught_for(address: str, cfg: dict) -> tuple:
    """Return (category, is_exact_address) for a taught sender."""
    taught = cfg.get("taught") or {}
    if address in taught:
        return taught[address], True
    parts = address.rpartition("@")[2].split(".")
    for start in range(len(parts) - 1):
        hit = taught.get(".".join(parts[start:]))
        if hit:
            return hit, False
    return None, False


def protected_bucket(msg: dict, cfg: dict, now: datetime, strong: re.Pattern, soft: re.Pattern) -> str | None:
    """Return why this message must stay in the Inbox, or None. The model never sees mail with a bucket."""
    keywords, robot = msg["keywords"], bool(ROBOT_LOCALPART.match(msg["localpart"])) or msg["auto"]
    bulk = msg["list"] or msg["tag"].startswith(("commercial", "community"))
    if not SAFE_ADDRESS.fullmatch(msg["address"]):
        return "odd-wording"
    if keywords.get("$flagged") or keywords.get("$notify") or keywords.get("$followed"):
        return "flagged"
    if keywords.get("$answered") or keywords.get("$draft"):
        return "conversation"
    if keywords.get("$phishing") or msg["tag"].startswith(ALARM_TAGS):
        return "suspicious"
    if msg["domain"] in cfg["own_domains"] or msg["address"] in cfg["own_addresses"]:
        return "self"
    if msg["known"] and not robot:
        return "person"
    if (msg["reply"] or REPLY_SUBJECT.match(msg["subject_match"])) and not robot and not msg["list"] and not msg["tag"].startswith("commercial"):
        return "conversation"
    if domain_matches(msg["domain"], cfg["freemail_domains"]) and not robot and not msg["list"]:
        return "person"
    if BOUNCE_LOCALPART.match(msg["localpart"]):
        return "bounce"
    if any(looks_like_injection(field) for field in msg["fields"]) or MIXED_SCRIPT.search(f"{msg['fields'][0]} {msg['fields'][1]}"):
        return "odd-wording"
    if set(msg["aliases"]) & set(cfg["protected_aliases"]) or domain_matches(msg["domain"], cfg["protected_domains"]):
        return "protected"
    if strong.search(msg["subject_match"]):
        return "attention"
    if not bulk and soft.search(msg["subject_match"]):
        return "attention-soft"
    if not (robot or msg["list"] or (msg["tag"] and msg["tag"] != "clean")):
        return "unknown"  # no sign of a machine, so treat it as a person not yet in Contacts
    try:
        age = now - datetime.fromisoformat(msg["received"].replace("Z", "+00:00"))
    except ValueError:
        return "unknown"
    return "too-new" if age < timedelta(hours=cfg["min_age_hours"]) else None


def conversation_threads(jm, messages: list, sent_id: str | None) -> set:
    """Thread ids holding something you sent or followed. Those are conversations, whatever the sender looks like."""
    thread_ids = sorted({m["thread"] for m in messages if m.get("thread")})
    if not thread_ids:
        return set()
    members = {t["id"]: t.get("emailIds", []) for t in get_all(jm, "Thread/get", thread_ids)}
    known = {m["id"] for m in messages}
    other = sorted({e for ids in members.values() for e in ids if e not in known})
    marked = {e["id"] for e in get_all(jm, "Email/get", other, ["id", "mailboxIds", "keywords"])
              if (sent_id and sent_id in (e.get("mailboxIds") or {})) or (e.get("keywords") or {}).get("$followed")}
    return {t for t, ids in members.items() if marked.intersection(ids)}


# ---------------------------------------------------------------- Hermes contract
def hermes_jobs() -> list:
    jobs = read_json(hermes_home() / "cron" / "jobs.json", {})
    jobs = jobs.get("jobs", []) if isinstance(jobs, dict) else []
    return jobs if isinstance(jobs, list) else []


def job_named(name: str) -> dict | None:
    return next((j for j in hermes_jobs() if j.get("name") == name), None)


def tool_gate_problem() -> str | None:
    """The model reads text written by strangers, so its cron job must have no tools at all."""
    job = job_named(DECIDE_JOB)
    if job is None:
        return f"the Hermes job {DECIDE_JOB} is missing"
    if job.get("enabled_toolsets") != []:
        return f"the Hermes job {DECIDE_JOB} has tools enabled (its enabled_toolsets must be [])"
    return None


def agent_output_docs(since: float) -> list:
    job = job_named(DECIDE_JOB)
    pattern = f"{job['id']}/*.md" if job and job.get("id") else "*/*.md"
    docs = [p for p in (hermes_home() / "cron" / "output").glob(pattern) if p.stat().st_mtime >= since - 1]
    return sorted(docs, key=lambda p: p.stat().st_mtime, reverse=True)


def decisions_from_text(text: str, run_id: str) -> dict | None:
    """Pull the decisions out of a saved cron document. Only the model's response counts, never the prompt."""
    heading = text.rfind("## Response")
    if heading < 0:
        return None
    body = text[heading:]
    candidates = re.findall(r"```(?:json)?\s*(\{.*?\})\s*```", body, re.S)
    if "{" in body and "}" in body:
        candidates.append(body[body.index("{"): body.rindex("}") + 1])
    for raw in reversed(candidates):
        try:
            data = json.loads(raw)
        except (ValueError, RecursionError):
            continue
        if isinstance(data, dict) and data.get("run_id") == run_id:
            return data
    return None


# ---------------------------------------------------------------- scan
def cmd_scan(args) -> int:
    if not args.cron or os.environ.get("FASTMAIL_TRIAGE_JOB") != "1":  # the launcher sets this; a chat terminal must not get a digest
        print(f"The scan only runs inside its Hermes job. Run: hermes cron run {DECIDE_JOB}")
        return 0
    gate = tool_gate_problem()  # before anything else, so a job with tools can never get a digest
    try:
        digest = scan_inbox(gate)
    except Exception as exc:  # Hermes wakes the model on a failed script, so fail quietly and let apply report it
        reason = str(exc) if isinstance(exc, TriageError) else f"unexpected {type(exc).__name__}"
        write_private(data_dir() / "pending.json", json.dumps({"scan_error": reason, "created_ts": time.time()}))
        digest = None
    print(digest or '{"wakeAgent": false}')
    return 0


def scan_inbox(gate: str | None) -> str | None:
    cfg = load_config()
    problem = identity_problem(cfg)
    if problem:
        raise TriageError(problem)
    jm = connect()
    boxes = mailboxes(jm)
    inbox = boxes["role"]["inbox"]
    now = datetime.now(timezone.utc)
    strong, soft = phrase_regex(cfg["protected_strong_phrases"]), phrase_regex(cfg["protected_soft_phrases"])
    ids = query_ids(jm, {"inMailbox": inbox}, cfg["max_inbox_scan"])
    messages = [normalize(e, cfg) for e in get_all(jm, "Email/get", ids, PROPS)]
    state = load_state()
    in_inbox = set(ids)
    state["settled"] = {i: v for i, v in state["settled"].items() if i in in_inbox}

    kept: dict = collections.defaultdict(list)
    taught_msgs, candidates = [], []
    for msg in messages:
        rule, exact = taught_for(msg["address"], cfg)
        bucket = protected_bucket(msg, cfg, now, strong, soft)
        moving_rule = rule not in (None, STAY)
        if msg["id"] in state["settled"]:
            kept["settled"].append(msg)
        elif bucket and not (moving_rule and exact and bucket in cfg["address_rule_overrides"]):
            kept[bucket].append(msg)
        elif moving_rule and strong.search(msg["subject_match"]):  # a rule frees a sender, never an urgent subject
            kept["attention"].append(msg)
        elif rule == STAY:
            kept["taught-stay"].append(msg)
        elif moving_rule:
            taught_msgs.append((rule, msg))
        else:
            candidates.append(msg)
    active = conversation_threads(jm, candidates + [m for _, m in taught_msgs], boxes["role"].get("sent"))
    if active:
        kept["conversation"].extend(m for m in candidates if m["thread"] in active)
        kept["conversation"].extend(m for _, m in taught_msgs if m["thread"] in active)
        candidates = [m for m in candidates if m["thread"] not in active]
        taught_msgs = [(r, m) for r, m in taught_msgs if m["thread"] not in active]

    groups = collections.defaultdict(list)
    for msg in candidates:  # one decision per kind of mail, so a person's note is not hidden behind a sender's bulk mail
        groups[(msg["address"], msg["list"])].append(msg)
    per_domain: collections.Counter = collections.Counter()
    records, plan_groups = [], []
    for (address, is_list), msgs in sorted(groups.items(), key=lambda kv: max(m["received"] for m in kv[1]), reverse=True):
        domain = address.rpartition("@")[2]
        per_domain[domain] += 1
        if per_domain[domain] > cfg["max_groups_per_domain"] or len(records) >= cfg["max_groups_in_digest"]:
            kept["over-limit"].extend(msgs)
            continue
        subjects, shown = [], []
        for msg in msgs:  # the model decides for every message in a group, so it must see every distinct subject
            if msg["subject"] in subjects or len(subjects) < cfg["max_subjects_per_group"]:
                subjects += [] if msg["subject"] in subjects else [msg["subject"]]
                shown.append(msg)
            else:
                kept["over-limit"].append(msg)
        tags = collections.Counter(m["tag"] for m in shown if m["tag"])
        record = {"k": f"S{len(records) + 1}", "from": address, "name": shown[0]["name"],
                  "alias": sorted({a for m in shown for a in m["aliases"]})[:2], "n": len(shown),
                  "tag": tags.most_common(1)[0][0] if tags else "", "list": int(is_list),
                  "robot": int(any(ROBOT_LOCALPART.match(m["localpart"]) or m["auto"] for m in shown)), "subjects": subjects}
        if looks_like_injection(json.dumps(record, ensure_ascii=False)):  # only appears once the fields are combined
            kept["odd-wording"].extend(shown)
            continue
        records.append(record)
        plan_groups.append({"k": record["k"], "address": address, "ids": [m["id"] for m in shown]})

    run_id = secrets.token_hex(8)
    digest = render_digest(run_id, records)
    if looks_like_injection(digest):
        gate = gate or "the digest still matched an injection pattern after cleaning"
    pending = {
        "version": 2, "run_id": run_id, "created_ts": now.timestamp(), "inbox": inbox, "scanned": len(messages),
        "truncated": len(ids) >= cfg["max_inbox_scan"], "agent_expected": bool(records) and not gate,
        "gate_problem": gate, "groups": plan_groups,
        "taught": [{"id": m["id"], "address": m["address"], "category": rule} for rule, m in taught_msgs],
        "kept": {bucket: [{"address": m["address"], "unread": not m["keywords"].get("$seen"), "known": m["known"]}
                          for m in msgs] for bucket, msgs in kept.items()},
    }
    write_private(data_dir() / "pending.json", json.dumps(pending, indent=1))
    save_state(state)
    return digest if records and not gate else None


def render_digest(run_id: str, records: list) -> str:
    lines = [f"{DIGEST_HEADER} {run_id}: {len(records)} sender groups"]
    lines.extend(json.dumps(record, ensure_ascii=False) for record in records)
    return "\n".join(lines)


# ---------------------------------------------------------------- apply
def wait_for_decisions(pending: dict, cfg: dict, cron: bool) -> tuple:
    if not pending.get("agent_expected"):
        return None, None
    deadline = time.time() + (cfg["agent_wait_minutes"] * 60 if cron else 0)
    while True:
        blocked = None
        for doc in agent_output_docs(pending["created_ts"]):
            text = doc.read_text(encoding="utf-8", errors="replace")
            data = decisions_from_text(text, pending["run_id"])
            if data:
                return data, None
            if "injection scanner" in text:
                blocked = "Hermes's prompt scanner blocked the agent step"
        if blocked or time.time() >= deadline:
            return None, blocked or "the agent step produced no usable decisions"
        time.sleep(15)


def plan_moves(pending: dict, data: dict | None, cfg: dict) -> dict:
    """Turn decisions into moves. Anything unknown, misshapen or left out means Stay."""
    allowed, groups = set(cfg["folders"]), {g["k"]: g for g in pending["groups"]}
    items = (data or {}).get("decisions")
    choices = {i["k"]: i["category"] for i in (items if isinstance(items, list) else [])
               if isinstance(i, dict) and isinstance(i.get("k"), str) and isinstance(i.get("category"), str) and i["k"] in groups}
    queue = [{"id": t["id"], "category": t["category"], "address": t["address"]} for t in pending.get("taught", [])
             if t["category"] in allowed and taught_for(t["address"], cfg)[0] == t["category"]]  # a rule may have changed
    stay, answered_stay = [], []
    for key, group in groups.items():
        if choices.get(key) in allowed and taught_for(group["address"], cfg)[0] != STAY:
            queue.extend({"id": i, "category": choices[key], "address": group["address"]} for i in group["ids"])
        else:
            stay.append(group)
            if choices.get(key) == STAY:
                answered_stay.append(group)
    moves, held, per_sender = [], 0, collections.Counter()
    for move in queue:  # taught mail comes first; limits hold mail back for next week and never block a whole run
        if len(moves) >= cfg["max_moves_per_run"] or per_sender[move["address"]] >= cfg["max_moves_per_sender"]:
            held += 1
            continue
        per_sender[move["address"]] += 1
        moves.append(move)
    looks = (data or {}).get("look")
    look = [groups[k]["address"] for k in (looks if isinstance(looks, list) else []) if isinstance(k, str) and k in groups][:5]
    malformed = data is not None and not isinstance(items, list)
    return {"moves": moves, "stay": stay, "answered_stay": answered_stay, "look": list(dict.fromkeys(look)), "held": held, "malformed": malformed}


def cmd_apply(args) -> int:
    cfg = load_config()
    path = data_dir() / "pending.json"
    deadline = time.time() + (cfg["agent_wait_minutes"] * 60 if args.cron else 0)
    while not path.exists() and time.time() < deadline:  # after downtime both jobs can start together
        time.sleep(15)
    if not path.exists():
        print("Fastmail sort: there is no scan waiting, so nothing moved. Did the fastmail-triage-decide job run?")
        return 0
    pending = read_json(path, {})
    if pending.get("scan_error"):
        path.unlink()
        print(f"Fastmail sort did not run, and no mail moved. The scan failed: {pending['scan_error']}")
        return 0
    if not pending.get("run_id"):
        path.unlink()
        print("Fastmail sort: the saved scan was unreadable, so nothing moved.")
        return 0
    age_hours = (time.time() - pending["created_ts"]) / 3600
    if age_hours > cfg["max_plan_age_hours"]:
        path.unlink()
        print(f"Fastmail sort: the last scan is {age_hours:.0f} hours old, so nothing moved.")
        return 0

    problems = []
    if pending.get("gate_problem"):
        problems.append(f"Agent step skipped: {pending['gate_problem']}.")
    data, why = wait_for_decisions(pending, cfg, args.cron)
    if why:
        problems.append(f"Senders it hasn't seen before stayed in the Inbox: {why}.")
    plan = plan_moves(pending, data, cfg)
    if plan["malformed"]:
        problems.append("The agent's answer was malformed, so senders it hasn't seen before stayed in the Inbox.")
    mode = cfg["mode"]
    jm = connect()
    boxes = mailboxes(jm)
    inbox = boxes["role"]["inbox"]
    moves = plan["moves"]
    missing = sorted({m["category"] for m in moves if cfg["folders"][m["category"]] not in boxes["name"]})
    if missing:
        problems.append(f"Missing folders, so their mail stayed put: {', '.join(missing)}.")
    moves = [m for m in moves if m["category"] not in missing]

    # You may have dealt with something since the scan. Look again right before moving.
    current = {e["id"]: e for e in get_all(jm, "Email/get", [m["id"] for m in moves], ["id", "mailboxIds", "keywords"])}
    runnable, skipped = [], 0
    for move in moves:
        email = current.get(move["id"]) or {}
        if inbox in (email.get("mailboxIds") or {}) and not any((email.get("keywords") or {}).get(k) for k in HANDS_OFF_KEYWORDS):
            runnable.append(move)
        else:
            skipped += 1

    moved, failed, unsure = [], [], 0
    if mode == "apply":
        journal_path = data_dir() / "runs" / f"{pending['run_id']}.json"
        journal = read_json(journal_path, None) or {"run_id": pending["run_id"], "at": datetime.now(timezone.utc).isoformat(), "inbox": inbox, "moved": []}
        step = getattr(jm, "max_set", 100)
        for start in range(0, len(runnable), step):
            chunk = runnable[start:start + step]
            update = {}
            for move in chunk:
                move["to"] = boxes["name"][cfg["folders"][move["category"]]]
                update[move["id"]] = {f"mailboxIds/{inbox}": None, f"mailboxIds/{move['to']}": True}
            # Recorded before the call: undo only touches mail really in the target folder, so an intent is harmless.
            journal["moved"].extend({"id": m["id"], "to": m["to"], "category": m["category"], "address": m["address"]} for m in chunk)
            write_private(journal_path, json.dumps(journal, indent=1))
            try:
                done = jm.method("Email/set", {"update": update}).get("updated") or {}
            except TriageError as exc:
                try:  # the call may have worked and only the reply been lost
                    now_at = {e["id"]: e.get("mailboxIds") or {} for e in get_all(jm, "Email/get", list(update), ["id", "mailboxIds"])}
                    moved.extend(m for m in chunk if m["to"] in now_at.get(m["id"], {}))
                except TriageError:
                    unsure = len(chunk)
                problems.append(f"Stopped after {len(moved)} moves: {exc}" + (f" Up to {unsure} more may have moved, and undo will find them." if unsure else " The rest stayed in the Inbox."))
                break
            for move in chunk:
                (moved if move["id"] in done else failed).append(move)
        if moved or unsure:
            prune_runs()
        else:
            journal_path.unlink(missing_ok=True)  # a run that moved nothing leaves nothing for undo to find
        if data is not None and not plan["malformed"]:  # ask about each message once: a Stay holds until you teach a rule
            state = load_state()
            state["settled"].update({i: {"why": "stay", "address": g["address"]} for g in plan["answered_stay"] for i in g["ids"]})
            save_state(state)
    cleared = forget_agent_run(data is not None)
    if cleared:
        problems.append(cleared)
    path.unlink()  # a scan can only be applied once, even if the report below fails

    done_moves = moved if mode == "apply" else runnable
    try:
        items = report_items(pending, cfg, mode, done_moves, failed, skipped, plan, problems, jm, boxes)
    except Exception as exc:  # the moves have happened, so always say so
        items = [(f"Fastmail weekly sort: {len(done_moves)} messages {'moved' if mode == 'apply' else 'would move'}. "
                  f"The rest of the report failed ({type(exc).__name__}).", None)]
    # The copy kept on disk is what a chat session reads, and even a checked address is text from a stranger.
    write_private(data_dir() / "last-report.txt", scrub_report(format_report(items, False)) + "\nSender addresses are in the copy sent to the report channel.\n")
    print(scrub_report(format_report(items, True)))
    return 0


def digest_sessions(job_id: str) -> list | None:
    """Cron sessions holding a digest, or None if Hermes has no session store here.

    Session ids differ by Hermes version and by how the job started, so also look for the job's title and the digest itself.
    """
    database = hermes_home() / "state.db"
    if not database.exists():
        return None

    def like(text: str) -> str:
        return re.sub(r"([%_\\])", r"\\\1", text)

    db = sqlite3.connect(f"file:{urllib.parse.quote(str(database))}?mode=ro", uri=True, timeout=10)
    try:
        return [row[0] for row in db.execute(
            "SELECT s.id FROM sessions s WHERE s.source = 'cron' AND (s.id LIKE ? ESCAPE '\\' OR s.title LIKE ? ESCAPE '\\' "
            "OR EXISTS (SELECT 1 FROM messages m WHERE m.session_id = s.id AND m.content LIKE ? ESCAPE '\\'))",
            (like(f"cron_{job_id}_") + "%", like(DECIDE_JOB) + " %", "%" + like(DIGEST_HEADER) + "%"))]
    finally:
        db.close()


def forget_agent_run(model_answered: bool) -> str | None:
    """Hermes keeps each cron run's prompt in a searchable session store, and a chat agent with a terminal can search it.

    If the model answered, its session must exist. Finding none means Hermes stores sessions differently now, so say so
    rather than report a clean run.
    """
    job = job_named(DECIDE_JOB)
    if not job or not job.get("id"):
        return None
    problem = "Could not clear this run from Hermes's history, so a chat search could still find subject lines from it."
    try:
        for doc in (hermes_home() / "cron" / "output" / str(job["id"])).glob("*.md"):
            doc.unlink()
        ids = digest_sessions(job["id"])
        if ids is None:
            return None
        if model_answered and not ids:
            return problem
        hermes = shutil.which("hermes") or shutil.which("hermes", path=str(Path.home() / ".local" / "bin"))
        if ids and not hermes:
            return problem
        for session in ids:
            result = subprocess.run([hermes, "sessions", "delete", session, "--yes"], capture_output=True, timeout=60,
                                    env={**os.environ, "HERMES_HOME": str(hermes_home())})
            if result.returncode != 0:
                return problem
        if digest_sessions(job["id"]):  # trust the store, not the exit code
            return problem
    except Exception:  # never let tidying up cost you the report
        return problem
    return None


def prune_runs(keep: int = 26) -> None:
    runs = sorted((data_dir() / "runs").glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    for old in runs[keep:]:
        old.unlink()


def scrub_report(text: str) -> str:
    """A last line of defence: Hermes treats MEDIA: tags and [[...]] directives in delivered text as commands."""
    text = re.sub(r"(?i)media\s*:", "media -", text)
    return text.replace("[[", "(").replace("]]", ")")


def safe_address(address: str) -> str:
    """An address can spell out a sentence, so only short, plain ones are printed."""
    if not SAFE_ADDRESS.fullmatch(address or ""):
        return "(unusual address)"
    local, _, domain = address.partition("@")
    if "%" in local or len(local) > 30 or len(domain) > 30 or len(re.findall(r"[._+\-]", local)) > 3 or len(re.findall(r"-", domain)) > 3:
        return "(long address)"
    return address


def address_list(addresses, shown: int = 6) -> str:
    counts: dict = {}  # keeps first-seen order, so whoever the caller put first stays first
    for address in addresses:
        label = safe_address(address)
        counts[label] = counts.get(label, 0) + 1
    parts = [f"{a} ({n})" if n > 1 else a for a, n in list(counts.items())[:shown]]
    return ", ".join(parts) + (f", and {len(counts) - shown} more" if len(counts) > shown else "")


def query_senders(jm, flt: dict) -> tuple:
    result = jm.method("Email/query", {"filter": flt, "sort": [{"property": "receivedAt", "isAscending": False}], "limit": 20, "calculateTotal": True})
    ids = result.get("ids", [])
    emails = get_all(jm, "Email/get", ids, ["from"])
    return result.get("total", len(ids)), [str(((e.get("from") or [{}])[0] or {}).get("email") or "").lower() for e in emails]


def report_items(pending, cfg, mode, moves, failed, skipped, plan, problems, jm, boxes) -> list:
    """The report as (fixed text, sender addresses or None). Every word except a checked address is written here."""
    verb = "Moved" if mode == "apply" else "Would move"
    items = [(f"Fastmail weekly sort, {datetime.now().strftime('%a %-d %b')}" + ("" if mode == "apply" else " (PROPOSAL: nothing moved)"), None),
             (f"{verb} {len(moves)} of the {pending['scanned']} Inbox messages.", None)]
    by_category = collections.defaultdict(list)
    for move in moves:
        by_category[move["category"]].append(move["address"])
    items.extend((f"- {category} {len(by_category[category])}", by_category[category]) for category in sorted(by_category))
    if plan["held"]:
        items.append((f"{plan['held']} more were held back by the limits and wait for the next run.", None))
    if failed:
        items.append((f"{len(failed)} moves failed and stayed in the Inbox.", None))
    if skipped:
        items.append((f"{skipped} messages changed since the scan and were left alone.", None))
    items.extend((problem, None) for problem in problems)
    if plan["look"]:
        items.append((f"\nWorth a look, says the model: {len(plan['look'])}", plan["look"]))

    def section(title, flt):
        try:
            total, senders = query_senders(jm, flt)
        except (TriageError, KeyError, ValueError, TypeError, AttributeError):
            items.append((f"\nCould not read: {title}.", None))
            return
        if total:
            items.append((f"\n{title}: {total}", senders))

    inbox = pending["inbox"]
    section("Flagged in the Inbox", {"inMailbox": inbox, "hasKeyword": "$flagged"})
    since = (datetime.now(timezone.utc) - timedelta(days=8)).strftime("%Y-%m-%dT%H:%M:%SZ")
    renewals = boxes["name"].get(cfg["folders"].get("Subscriptions", ""))
    if renewals:
        section("Renewals flagged in Subscriptions this week", {"inMailbox": renewals, "hasKeyword": "$flagged", "after": since})
    kept = pending["kept"]
    people = [p for bucket in ("person", "conversation") for p in kept.get(bucket, []) if p["unread"]]
    people.sort(key=lambda p: not p["known"])  # contacts first, so a crowd of strangers cannot push them off the list
    if people:
        items.append((f"\nUnread from people: {len(people)}", [p["address"] for p in people]))
    undecided = [u["address"] for u in kept.get("unknown", [])] + [s["address"] for s in kept.get("settled", [])]
    undecided += [a for g in plan["stay"] for a in [g["address"]] * len(g["ids"])]
    if undecided:
        items.append((f"\nNot sorted, for you to decide: {len(undecided)}", undecided))
    suspicious = kept.get("suspicious", []) + kept.get("odd-wording", [])
    if suspicious:
        items.append((f"\nLeft in the Inbox because they look suspicious or their wording is odd: {len(suspicious)}", [s["address"] for s in suspicious]))
    spam = boxes["role"].get("junk")
    if spam:
        try:
            count = jm.method("Email/query", {"filter": {"inMailbox": spam, "after": since}, "limit": 1, "calculateTotal": True}).get("total", 0)
            if count:
                items.append((f"\nNew in Spam this week: {count}. Worth a quick check for anything real.", None))
        except TriageError:
            items.append(("\nCould not read the Spam folder.", None))
    counts = ", ".join(f"{bucket} {len(found)}" for bucket, found in sorted(kept.items()))
    items.append((f"\nKept in the Inbox: {counts or 'nothing'}", None))
    if pending.get("truncated"):
        items.append((f"The Inbox holds more than {cfg['max_inbox_scan']} messages, and only the newest were scanned.", None))
    if mode == "apply" and moves:
        items.append((f"To undo, ask Hermes or run: fastmail_triage.py undo --run {pending['run_id']}", None))
    return items


def format_report(items: list, with_addresses: bool) -> str:
    return "\n".join(f"{text} ({address_list(senders)})" if senders and with_addresses else text for text, senders in items)


# ---------------------------------------------------------------- other commands
def cmd_undo(args) -> int:
    runs = data_dir() / "runs"
    if args.run:
        if not re.fullmatch(r"[0-9a-f]{16}", args.run):
            raise TriageError("That run id does not look right.")
        path = runs / f"{args.run}.json"
        if not path.exists():
            raise TriageError("There is no such run to undo.")
    else:
        journals = [(read_json(p, {}), p) for p in runs.glob("*.json")]
        live = [(j.get("at", ""), p) for j, p in journals if any(not e.get("undone") for e in j.get("moved", []))]
        if not live:
            raise TriageError("There is nothing left to undo.")
        path = max(live)[1]
    journal = json.loads(path.read_text(encoding="utf-8"))
    jm = connect()
    entries = [e for e in journal["moved"] if not e.get("undone")]
    current = {e["id"]: e for e in get_all(jm, "Email/get", [e["id"] for e in entries], ["id", "mailboxIds"])}
    update = {e["id"]: {f"mailboxIds/{e['to']}": None, f"mailboxIds/{journal['inbox']}": True} for e in entries
              if e["to"] in ((current.get(e["id"]) or {}).get("mailboxIds") or {})}
    done: set = set()
    ids, step = list(update), getattr(jm, "max_set", 100)
    for start in range(0, len(ids), step):
        done.update(jm.method("Email/set", {"update": {i: update[i] for i in ids[start:start + step]}}).get("updated") or {})
    state = load_state()
    for entry in entries:
        if entry["id"] in done:
            entry["undone"] = True
            state["settled"][entry["id"]] = {"why": "undone", "address": entry["address"]}  # later runs leave these alone
    write_private(path, json.dumps(journal, indent=1))
    save_state(state)
    print(f"Undid run {journal['run_id']} from {journal.get('at', '')[:10]}: moved {len(done)} messages back to the Inbox, "
          f"and {len(entries) - len(done)} had already moved elsewhere and were left alone. Later runs leave these alone unless you teach a rule for the sender.")
    return 0


def cmd_report(_args) -> int:
    path = data_dir() / "last-report.txt"
    print(path.read_text(encoding="utf-8").rstrip() if path.exists() else "There is no report yet.")
    return 0


def cmd_mode(args) -> int:
    mine = user_config()
    if args.value:
        mine["mode"] = args.value
        save_user_config(mine)
    current = mine.get("mode", "propose")
    print(f"Mode: {current}" + (" (reports only, nothing moves)" if current == "propose" else " (mail moves)"))
    return 0


def cmd_teach(args) -> int:
    cfg, mine = load_config(), user_config()
    if args.category != STAY and args.category not in cfg["folders"]:
        raise TriageError(f"Category must be one of: {', '.join(cfg['folders'])}, {STAY}.")
    sender = args.sender.strip().lower().lstrip("@")
    if "@" in sender:
        if not SAFE_ADDRESS.fullmatch(sender):
            raise TriageError("That does not look like an email address.")
        covers = "only that address"
    else:
        if not re.fullmatch(r"[a-z0-9\-]+(\.[a-z0-9\-]+)+", sender) or sender in cfg["public_suffixes"]:
            raise TriageError("Give a full address or a company's domain, such as shop@example.com or example.com.")
        if args.category != STAY and (domain_matches(sender, cfg["freemail_domains"]) or domain_matches(sender, cfg["own_domains"]) or domain_matches(sender, cfg["protected_domains"])):
            raise TriageError("That domain covers people or protected mail, so it can only be taught one full address at a time.")
        covers = "automated mail from that domain and its subdomains. Mail that looks like it's from a person still stays"
    mine.setdefault("taught", {})[sender] = args.category
    save_user_config(mine)
    state = load_state()  # a rule taught now answers any question left open about this sender
    released = [i for i, v in state["settled"].items() if isinstance(v, dict) and (v.get("address") == sender or domain_matches(str(v.get("address", "")).rpartition("@")[2], [sender]))]
    if args.category != STAY:
        for message in released:
            del state["settled"][message]
        save_state(state)
    print(f"{sender} now goes to {args.category}. This covers {covers}. Flagged mail, conversations and urgent subjects still stay put.")
    return 0


def cmd_set_token(_args) -> int:
    token = (getpass.getpass("Fastmail API token: ") if sys.stdin.isatty() else sys.stdin.readline()).strip()
    if not token or re.search(r"\s", token):
        raise TriageError("That doesn't look like a token, so nothing was saved.")
    write_private(data_dir() / "token", token + "\n")
    print("Token saved. Run check next.")
    return 0


def cmd_check(_args) -> int:
    cfg = load_config()
    failures = 0

    def line(ok, text):
        nonlocal failures
        failures += 0 if ok else 1
        print(f"{'ok  ' if ok else 'FAIL'} {text}")

    problem = identity_problem(cfg)
    line(not problem, problem or "your own addresses are set")
    env_file = hermes_home() / ".env"
    in_env = env_file.exists() and "FASTMAIL_API_TOKEN=" in env_file.read_text(encoding="utf-8", errors="replace")
    line(not in_env, "the token is not in ~/.hermes/.env, where every Hermes terminal could read it")
    token_file = data_dir() / "token"
    line(not token_file.exists() or not stat.S_IMODE(token_file.stat().st_mode) & 0o077, "the token file is private")
    try:
        jm = connect()
    except TriageError as exc:
        line(False, str(exc))
        return 1
    line(True, "Fastmail accepted the token")
    account = jm.session.get("accounts", {}).get(jm.account, {})
    line(not account.get("isReadOnly"), "the token can move mail (it needs the Email scope)")
    line("urn:ietf:params:jmap:submission" not in account.get("accountCapabilities", {}), "the token cannot send mail (no Email submission scope)")
    boxes = mailboxes(jm)
    for category, folder in cfg["folders"].items():
        line(folder in boxes["name"], f"folder {folder} exists for {category}")
    gate = tool_gate_problem()
    line(not gate, gate or f"{DECIDE_JOB} runs with no tools")
    apply_job = job_named(APPLY_JOB)
    line(bool(apply_job and apply_job.get("no_agent")), f"{APPLY_JOB} exists as a script-only job")
    for name in (DECIDE_JOB, APPLY_JOB):
        job = job_named(name) or {}
        line(job.get("enabled") is not False and job.get("state") != "paused", f"{name} is not paused")
    if apply_job:
        print(f"Report goes to: {clean_text(apply_job.get('deliver'), 60)}")
        if apply_job.get("last_delivery_error"):
            line(False, f"last report failed to deliver: {clean_text(apply_job['last_delivery_error'], 120)}")
    print(f"Mode: {cfg['mode']}")
    return 1 if failures else 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Sort a Fastmail Inbox with hard guardrails.")
    sub = parser.add_subparsers(dest="command", required=True)
    scan = sub.add_parser("scan")
    scan.add_argument("--cron", action="store_true", help="only for the Hermes job: prints text from strangers")
    scan.set_defaults(func=cmd_scan)
    apply_ = sub.add_parser("apply")
    apply_.add_argument("--cron", action="store_true", help="scheduled run: wait for the agent step's output")
    apply_.set_defaults(func=cmd_apply)
    undo = sub.add_parser("undo")
    undo.add_argument("--run")
    undo.set_defaults(func=cmd_undo)
    sub.add_parser("report").set_defaults(func=cmd_report)
    sub.add_parser("check").set_defaults(func=cmd_check)
    sub.add_parser("set-token").set_defaults(func=cmd_set_token)
    mode = sub.add_parser("mode")
    mode.add_argument("value", nargs="?", choices=["propose", "apply"])
    mode.set_defaults(func=cmd_mode)
    teach = sub.add_parser("teach")
    teach.add_argument("sender")
    teach.add_argument("category")
    teach.set_defaults(func=cmd_teach)
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except TriageError as exc:
        print(f"fastmail-triage: {exc}", file=sys.stderr)
    except Exception as exc:  # no traceback: it could quote mail text into an alert
        print(f"fastmail-triage: unexpected {type(exc).__name__}. No further mail was moved.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
