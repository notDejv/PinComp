#!/usr/bin/env python3
"""Generate data/<set>/champions.json and data/index.json from Community Dragon.

Sources:
  - tftchampions-teamplanner.json: per-set list of champions with team_planner_code,
    character_id, display_name, tier (cost) and a square icon path.
  - cdragon/tft/en_us.json: setData[mutator == <set>].champions, used for the
    256 px square icon (`squareIcon`) and to cross-check the cost.

Only the standard sets present in the team planner file are published.
The run fails if the validation code does not resolve completely.

Usage: python3 scripts/build_data.py [--out data]
"""

import argparse
import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request

TEAMPLANNER_URL = (
    "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/"
    "global/default/v1/tftchampions-teamplanner.json"
)
EN_US_URL = "https://raw.communitydragon.org/latest/cdragon/tft/en_us.json"
GAME_BASE = "https://raw.communitydragon.org/latest/game/"
PLUGIN_BASE = "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/"

SET_KEY = re.compile(r"^TFTSet(\d+)$")

# The user's real Set 18 comp; every slot must resolve or the run fails.
VALIDATION_CODE = "0242043A4004123E942A43C430401000TFTSet18"
VALIDATION_EXPECTED = [1056, 1082, 1024, 1042, 1001, 1066, 1084, 1072, 1025]

USER_AGENT = "PinComp-data/1.0 (+https://github.com/notDejv/PinComp)"


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.load(resp)


def url_ok(url):
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status == 200 and resp.headers.get("Content-Type", "").startswith("image/")
    except urllib.error.URLError:
        return False


def game_asset_url(path):
    """Community Dragon game asset: lowercase, .tex -> .png."""
    path = path.lower()
    if path.endswith(".tex"):
        path = path[: -len(".tex")] + ".png"
    return GAME_BASE + path


def plugin_asset_url(path):
    """Team planner icon path: /lol-game-data/assets/... -> plugins/.../default/..."""
    prefix = "/lol-game-data/assets/"
    path = path.lower()
    if path.startswith(prefix):
        path = path[len(prefix):]
    return PLUGIN_BASE + path


def decode_planner_code(raw):
    """Mirror of the Swift parser: '02' + 10 x 3 hex + 'TFTSet<N>'."""
    raw = raw.strip()
    idx = raw.rfind("TFTSet")
    if idx < 0:
        raise ValueError("missing set suffix")
    body, set_name = raw[:idx], raw[idx:]
    if body[:2] != "02":
        raise ValueError("unsupported version %r" % body[:2])
    slots = body[2:]
    if len(slots) != 30:
        raise ValueError("bad length %d" % len(slots))
    codes = [int(slots[i:i + 3], 16) for i in range(0, 30, 3)]
    return set_name, [c for c in codes if c != 0]


def build_set(set_name, planner_entries, en_us):
    set_data = next((s for s in en_us.get("setData", []) if s.get("mutator") == set_name), None)
    details = {c["apiName"]: c for c in (set_data or {}).get("champions", [])}
    if not details:
        print("warning: %s has no en_us setData; using team planner icons only" % set_name)

    champions = []
    for entry in planner_entries:
        code = entry.get("team_planner_code")
        if not code:
            continue
        cid = entry["character_id"]
        cost = entry.get("tier")
        detail = details.get(cid)
        if detail is not None and detail.get("cost") != cost:
            print("warning: %s cost mismatch planner=%s en_us=%s" % (cid, cost, detail.get("cost")))

        candidates = []
        if detail and detail.get("squareIcon"):
            candidates.append(game_asset_url(detail["squareIcon"]))
        if entry.get("squareIconPath"):
            candidates.append(plugin_asset_url(entry["squareIconPath"]))
        icon = next((u for u in candidates if url_ok(u)), None)
        if icon is None:
            raise SystemExit("error: no reachable icon for %s (%s)" % (cid, candidates))

        champions.append({
            "id": cid,
            "name": entry["display_name"],
            "cost": cost,
            "plannerCode": code,
            "icon": icon,
        })

    codes = [c["plannerCode"] for c in champions]
    if len(codes) != len(set(codes)):
        raise SystemExit("error: duplicate planner codes in %s" % set_name)
    champions.sort(key=lambda c: (c["cost"], c["name"], c["plannerCode"]))
    return champions


def write_if_changed(path, payload, compare_keys):
    """Write JSON; keep the old file (and its generatedAt) when the content is unchanged."""
    if os.path.exists(path):
        with open(path) as f:
            try:
                old = json.load(f)
            except ValueError:
                old = None
        if old is not None and all(old.get(k) == payload.get(k) for k in compare_keys):
            return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "data"))
    args = parser.parse_args()
    out = os.path.normpath(args.out)

    print("fetching team planner mapping...")
    planner = fetch_json(TEAMPLANNER_URL)
    print("fetching en_us champion data...")
    en_us = fetch_json(EN_US_URL)

    set_names = sorted((k for k in planner if SET_KEY.match(k)), key=lambda k: int(SET_KEY.match(k).group(1)))
    if not set_names:
        raise SystemExit("error: no TFTSet<N> keys in team planner file")
    latest = set_names[-1]

    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    built = {}
    for set_name in set_names:
        champions = build_set(set_name, planner[set_name], en_us)
        built[set_name] = champions
        payload = {"set": set_name, "generatedAt": now, "champions": champions}
        changed = write_if_changed(os.path.join(out, set_name, "champions.json"), payload, ["set", "champions"])
        print("%s: %d champions%s" % (set_name, len(champions), " (updated)" if changed else " (unchanged)"))

    write_if_changed(os.path.join(out, "index.json"), {"sets": set_names, "latest": latest}, ["sets", "latest"])
    print("latest: %s" % latest)

    # Validation: the user's real comp must resolve completely.
    v_set, v_codes = decode_planner_code(VALIDATION_CODE)
    if v_codes != VALIDATION_EXPECTED:
        raise SystemExit("error: validation code decoded to %s" % v_codes)
    if v_set not in built:
        raise SystemExit("error: validation set %s not published" % v_set)
    by_code = {c["plannerCode"]: c for c in built[v_set]}
    missing = [c for c in v_codes if c not in by_code]
    print("validation (%s):" % v_set)
    for c in v_codes:
        champ = by_code.get(c)
        print("  %d -> %s" % (c, "%s (%d)" % (champ["name"], champ["cost"]) if champ else "MISSING"))
    if missing:
        raise SystemExit("error: unresolved validation codes %s" % missing)
    return 0


if __name__ == "__main__":
    sys.exit(main())
