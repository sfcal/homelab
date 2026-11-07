#!/usr/bin/env python3
"""Short JSON answers from Radarr, Sonarr and Plex for the plex-fix skill.

Reads freely. The only changes it can make are grab, fail and search. It has no
way to delete or edit anything.
"""
import inspect
import json
import os
import re
import sys
import urllib.error
import urllib.request

USAGE = """commands:
  playing                     what Plex is playing now, with transcode decisions
  recent                      the last few things watched on Plex
  find <text>                 movies and shows matching the text
  episodes <seriesId> <season>
  file movie|episode <id>     the current file
  history movie|episode <id>  past grabs, imports and failures
  queue [movie|episode <id>]  downloads in progress, problems first
  releases movie|episode <id> replacements that should import (slow, searches every indexer)
  grab movie|episode <guid> <indexerId>
  fail movie|episode <historyId>  block a grabbed release and search again
  search movie|episode <id>   automatic search, for a title with no file"""

HOST = "10.2.0.5"
APPS = {
    "movie": (f"http://{HOST}:7878/api/v3", "RADARR_API_KEY"),
    "episode": (f"http://{HOST}:8989/api/v3", "SONARR_API_KEY"),
}


def call(url, headers, body=None, timeout=30):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Accept": "application/json", "Content-Type": "application/json", **headers}
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if data else "GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read()[:300].decode(errors='replace')}")
    return json.loads(raw) if raw else {}


def arr(kind, path, body=None, timeout=30):
    base, key = APPS[kind]
    return call(f"{base}{path}", {"X-Api-Key": os.environ[key]}, body, timeout)


def plex(path):
    return call(f"http://{HOST}:32400{path}", {"X-Plex-Token": os.environ["PLEX_TOKEN"]})["MediaContainer"]


def show(data):
    print(json.dumps(data, indent=1, ensure_ascii=False))


def plex_title(m):
    if m.get("grandparentTitle"):
        return f"{m['grandparentTitle']} S{m.get('parentIndex')}E{m.get('index')} {m.get('title')}"
    return f"{m.get('title')} ({m.get('year')})"


def playing():
    out = []
    for m in plex("/status/sessions").get("Metadata", []):
        part = (m.get("Media") or [{}])[0].get("Part") or [{}]
        streams = [{k: s.get(k) for k in ("codec", "channels", "audioChannelLayout", "colorTrc", "DOVIProfile", "language", "decision") if s.get(k)}
                   for s in part[0].get("Stream", []) if s.get("streamType") == 1 or s.get("selected")]
        ts = m.get("TranscodeSession") or {}
        out.append({"title": plex_title(m), "user": (m.get("User") or {}).get("title"),
                    "player": (m.get("Player") or {}).get("product"),
                    "transcoding": {k: ts.get(k) for k in ("videoDecision", "audioDecision", "audioCodec", "videoCodec") if ts.get(k)},
                    "streams": streams})
    show(out)


def recent():
    items = plex("/status/sessions/history/all?sort=viewedAt:desc&X-Plex-Container-Start=0&X-Plex-Container-Size=8").get("Metadata", [])
    show([plex_title(m) for m in items[:8]])


def squash(text):
    return re.sub(r"[^a-z0-9]", "", text.lower())


def find(text):
    want = squash(text)
    hit = lambda t: want in squash(t)
    out = [{"kind": "movie", "id": m["id"], "title": m["title"], "year": m.get("year"), "hasFile": m.get("hasFile")}
           for m in arr("movie", "/movie", timeout=60) if hit(m["title"])]
    out += [{"kind": "series", "seriesId": s["id"], "title": s["title"], "year": s.get("year"),
             "seasons": [x["seasonNumber"] for x in s.get("seasons", []) if x["seasonNumber"]]}
            for s in arr("episode", "/series", timeout=60) if hit(s["title"])]
    show(out[:15])


def episodes(series_id, season):
    show([{"id": e["id"], "episode": e["episodeNumber"], "title": e.get("title"), "hasFile": e.get("hasFile")}
          for e in arr("episode", f"/episode?seriesId={series_id}&seasonNumber={season}")])


def current_file(kind, item_id):
    """The title's record and its file, or None for the file."""
    if kind == "movie":
        item = arr(kind, f"/movie/{item_id}")
        return item, arr(kind, f"/moviefile/{item['movieFile']['id']}") if item.get("hasFile") else None
    item = arr(kind, f"/episode/{item_id}")
    return item, arr(kind, f"/episodefile/{item['episodeFileId']}") if item.get("hasFile") else None


def file_summary(f):
    if not f:
        return None
    info = f.get("mediaInfo") or {}
    return {"id": f["id"], "name": f.get("sceneName") or f.get("relativePath"), "group": f.get("releaseGroup"),
            "quality": f["quality"]["quality"]["name"], "revision": f["quality"]["revision"]["version"],
            "formatScore": f.get("customFormatScore"), "formats": [c["name"] for c in f.get("customFormats", [])],
            "gb": round(f.get("size", 0) / 1e9, 1), "added": f.get("dateAdded"),
            "hdr": info.get("videoDynamicRangeType") or "SDR", "video": info.get("videoCodec"),
            "audio": info.get("audioCodec"), "channels": info.get("audioChannels"), "languages": info.get("audioLanguages")}


def file_cmd(kind, item_id):
    item, f = current_file(kind, item_id)
    show({"title": item.get("title"), "hasFile": bool(f), "file": file_summary(f)})


def history_events(kind, item_id):
    if kind == "movie":
        return arr(kind, f"/history/movie?movieId={item_id}")
    return arr(kind, f"/history?episodeId={item_id}&pageSize=30").get("records", [])


def history(kind, item_id):
    events = sorted(history_events(kind, item_id), key=lambda e: e["date"], reverse=True)
    show([{"id": e["id"], "event": e["eventType"], "date": e["date"], "release": e.get("sourceTitle"),
           "message": (e.get("data") or {}).get("message")} for e in events[:12]])


def queue(kind=None, item_id=None):
    out = []
    for app, path in (("movie", "/queue?pageSize=50&includeMovie=true"), ("episode", "/queue?pageSize=50&includeSeries=true&includeEpisode=true")):
        for q in arr(app, path).get("records", []):
            out.append({"kind": app, "id": q.get("movieId") or q.get("episodeId"), "release": q.get("title"),
                        "status": q.get("status"), "state": q.get("trackedDownloadState"), "health": q.get("trackedDownloadStatus"),
                        "timeLeft": q.get("timeleft"), "error": q.get("errorMessage"),
                        "messages": [m for s in q.get("statusMessages", []) for m in s.get("messages", [])]})
    if kind:
        out = [q for q in out if q["kind"] == kind and q["id"] == int(item_id)]
    out.sort(key=lambda q: q["health"] == "ok")
    show(out[:20])


def quality_ranks(kind, profile_id):
    """Quality id -> rank in the profile. Later ranks higher; a group shares one rank."""
    ranks = {}
    for i, item in enumerate(arr(kind, f"/qualityprofile/{profile_id}")["items"]):
        for q in item.get("items") or [item]:
            ranks[q["quality"]["id"]] = i
    return ranks


def releases(kind, item_id):
    """Replacements that should import: not lower quality, revision or format score than the file."""
    item, f = current_file(kind, item_id)
    owner = item if kind == "movie" else arr(kind, f"/series/{item['seriesId']}")
    ranks = quality_ranks(kind, owner["qualityProfileId"])
    name = squash(owner["title"])
    tried = {e.get("sourceTitle") for e in history_events(kind, item_id) if e["eventType"] == "grabbed"}
    key = "movieId" if kind == "movie" else "episodeId"
    results = arr(kind, f"/release?{key}={item_id}", timeout=170)
    usable = []
    counts = {"found": len(results), "blocked": 0, "different_name": 0, "would_not_import": 0, "already_tried": 0, "season_packs": 0}
    for r in results:
        if any(not str(x).startswith("Existing file") for x in r.get("rejections", [])):
            counts["blocked"] += 1
        elif name not in squash(r["title"]):
            counts["different_name"] += 1
        elif r.get("title") in tried:
            counts["already_tried"] += 1
        elif r.get("fullSeason"):
            counts["season_packs"] += 1
        elif f and (ranks.get(r["quality"]["quality"]["id"], -1) < ranks.get(f["quality"]["quality"]["id"], -1)
                    or r["quality"]["revision"]["version"] < f["quality"]["revision"]["version"]
                    or r.get("customFormatScore", 0) < (f.get("customFormatScore") or 0)):
            counts["would_not_import"] += 1
        else:
            usable.append(r)

    def dv_only(t):
        return bool(re.search(r"\b(DV|DoVi|Dolby.?Vision)\b", t, re.I)) and not re.search(r"HDR", t, re.I)

    def formats(r):
        return [c["name"] for c in r.get("customFormats", [])]

    def avoid(r):
        return any(n.startswith(("LQ", "x265", "AV1", "BR-DISK", "Upscaled", "Generated")) for n in formats(r))

    def tier(r):
        return min((n[-2:] for n in formats(r) if " Tier " in n), default="99")

    usable.sort(key=lambda r: (dv_only(r["title"]), avoid(r), -r.get("customFormatScore", 0), tier(r), r.get("age", 0)))
    usable = list({r["title"]: r for r in reversed(usable)}.values())[::-1]
    show({"counts": counts, "current": file_summary(f), "releases": [
        {"title": r["title"], "quality": r["quality"]["quality"]["name"], "gb": round(r.get("size", 0) / 1e9, 1),
         "ageDays": r.get("age"), "formatScore": r.get("customFormatScore"), "formats": formats(r),
         "languages": [x["name"] for x in r.get("languages", [])], "dvOnly": dv_only(r["title"]),
         "guid": r["guid"], "indexerId": r["indexerId"]} for r in usable[:10]]})


def grab(kind, guid, indexer_id):
    r = arr(kind, "/release", {"guid": guid, "indexerId": int(indexer_id)}, timeout=60)
    show({"grabbed": r.get("title") or guid})


def fail(kind, history_id):
    arr(kind, f"/history/failed/{int(history_id)}", {})
    show({"markedFailed": int(history_id)})


def search(kind, item_id):
    body = {"name": "MoviesSearch", "movieIds": [int(item_id)]} if kind == "movie" else {"name": "EpisodeSearch", "episodeIds": [int(item_id)]}
    show({"started": arr(kind, "/command", body).get("name")})


COMMANDS = {"playing": playing, "recent": recent, "find": find, "episodes": episodes, "file": file_cmd,
            "history": history, "queue": queue, "releases": releases, "grab": grab, "fail": fail, "search": search}

if __name__ == "__main__":
    args = sys.argv[1:]
    try:
        command = COMMANDS[args[0]]
        inspect.signature(command).bind(*args[1:])
    except (IndexError, KeyError, TypeError):
        sys.exit(USAGE)
    command(*args[1:])
