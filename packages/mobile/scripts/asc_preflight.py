#!/usr/bin/env python3
"""Checks the live App Store Connect record for Memory Survival against the repo.

Read-only. Answers "is App Store Connect ready for this build to be
submitted?" without anyone clicking through the console: listing text and
screenshots, categories and age rating, review contact, price and
availability, the Unlock Premium purchase, Game Center, and the build.

Needs the same secrets the release workflow uses:
  APP_STORE_CONNECT_KEY (PEM or base64), APP_STORE_CONNECT_KEY_ID,
  APP_STORE_CONNECT_ISSUER_ID

Usage (from packages/mobile):
  python3 scripts/asc_preflight.py [--require-attached-build]

Exit status is 1 when any check FAILs. WARNs and MANUAL items never fail the
run. Needs: pip install pyjwt cryptography
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

MOBILE = Path(__file__).resolve().parents[1]
ROOT = MOBILE.parents[1]
META = MOBILE / "ios/fastlane/metadata"
BUNDLE_ID = "com.memorysurvival.app.ios"
EXPECTED_IAP_PRICE = "2.99"
EXPECTED_IAP_NAME = "Unlock Premium"

results: list[tuple[str, str, str]] = []  # (status, check, detail)


def record(status: str, check: str, detail: str = "") -> None:
    results.append((status, check, detail))


def ok(cond: bool, check: str, detail: str = "", warn_only: bool = False) -> bool:
    record("PASS" if cond else ("WARN" if warn_only else "FAIL"), check, "" if cond else detail)
    return cond


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


# --- App Store Connect API -------------------------------------------------


def private_key() -> str:
    raw = os.environ["APP_STORE_CONNECT_KEY"].strip()
    if "-----BEGIN" not in raw:
        try:
            decoded = base64.b64decode("".join(raw.split())).decode()
            if "-----BEGIN" in decoded:
                raw = decoded
        except Exception:
            pass
    return raw.replace("\\n", "\n")


def _ssl_context() -> ssl.SSLContext:
    # python.org builds on macOS ship without a CA bundle; use the system one.
    if not os.environ.get("SSL_CERT_FILE") and Path("/etc/ssl/cert.pem").exists():
        return ssl.create_default_context(cafile="/etc/ssl/cert.pem")
    return ssl.create_default_context()


_CTX = _ssl_context()
_TOKEN: str | None = None


def token() -> str:
    global _TOKEN
    if _TOKEN is None:
        now = int(time.time())
        _TOKEN = jwt.encode(
            {"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
            private_key(),
            algorithm="ES256",
            headers={"kid": os.environ["APP_STORE_CONNECT_KEY_ID"], "typ": "JWT"},
        )
    return _TOKEN


def get(path: str) -> dict:
    req = urllib.request.Request(
        "https://api.appstoreconnect.apple.com" + path, headers={"Authorization": "Bearer " + token()}
    )
    try:
        return json.load(urllib.request.urlopen(req, timeout=60, context=_CTX))
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()[:300]}


def data(r: dict):
    return None if "error" in r else r.get("data")


def code_value(path: str, pattern: str) -> str:
    m = re.search(pattern, (MOBILE / path).read_text(), re.MULTILINE)
    if not m:
        sys.exit(f"cannot find {pattern!r} in {path}")
    return m.group(1)


# --- Checks ----------------------------------------------------------------


def check_app() -> dict | None:
    r = get(f"/v1/apps?filter[bundleId]={BUNDLE_ID}&fields[apps]=name,primaryLocale,contentRightsDeclaration")
    apps = data(r)
    if not ok(bool(apps), "app record exists", f"no app for {BUNDLE_ID}: {r.get('body', '')}"):
        return None
    app = apps[0]
    a = app["attributes"]
    ok(a["name"] == read(META / "en-US/name.txt"), "app name matches metadata", f"ASC has {a['name']!r}")
    ok(a["primaryLocale"] == "en-US", "primary locale is en-US", a["primaryLocale"])
    ok(a["contentRightsDeclaration"] is not None, "content rights declaration answered", "not set")
    return app


def check_app_info(app_id: str) -> None:
    infos = data(get(f"/v1/apps/{app_id}/appInfos?include=primaryCategory"))
    if not ok(bool(infos), "app info exists"):
        return
    info = infos[0]
    cat = (info["relationships"]["primaryCategory"].get("data") or {}).get("id")
    ok(cat == "GAMES", "primary category is Games", f"got {cat}")
    ok(info["attributes"].get("appStoreAgeRating") is not None, "age rating questionnaire answered", "not answered")
    loc = data(get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")) or []
    en = next((x["attributes"] for x in loc if x["attributes"]["locale"] == "en-US"), None)
    if not ok(en is not None, "en-US app info localization exists"):
        return
    ok(en.get("subtitle") == read(META / "en-US/subtitle.txt"), "subtitle matches metadata", f"ASC: {en.get('subtitle')!r}")
    ok(en.get("privacyPolicyUrl") == read(META / "en-US/privacy_url.txt"), "privacy URL matches metadata", f"ASC: {en.get('privacyPolicyUrl')!r}")


def check_version(app_id: str, require_attached: bool) -> dict | None:
    versions = data(get(f"/v1/apps/{app_id}/appStoreVersions?limit=5")) or []
    if not ok(bool(versions), "an App Store version exists"):
        return None
    v = versions[0]
    va = v["attributes"]
    record("INFO", "version", f"{va['versionString']} {va['appStoreState']}")
    ok(va.get("copyright") == read(META / "copyright.txt"), "copyright matches metadata", f"ASC: {va.get('copyright')!r}")
    locs = data(get(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")) or []
    en = next((x for x in locs if x["attributes"]["locale"] == "en-US"), None)
    if ok(en is not None, "en-US listing exists"):
        a = en["attributes"]
        for field, f in [("description", "description"), ("keywords", "keywords"), ("promotionalText", "promotional_text"), ("supportUrl", "support_url")]:
            ok(a.get(field) == read(META / f"en-US/{f}.txt"), f"listing {field} matches metadata", "differs from fastlane/metadata (push_appstore_metadata lane)")
        sets = data(get(f"/v1/appStoreVersionLocalizations/{en['id']}/appScreenshotSets")) or []
        phone = [s for s in sets if s["attributes"]["screenshotDisplayType"].startswith("APP_IPHONE")]
        ok(bool(phone), "iPhone screenshots uploaded", "none")
        ipad = [s for s in sets if "IPAD" in s["attributes"]["screenshotDisplayType"]]
        ok(not ipad, "no iPad screenshots (iPhone-only game)", "iPad screenshot set present", warn_only=True)
        for s in phone:
            shots = data(get(f"/v1/appScreenshotSets/{s['id']}/appScreenshots")) or []
            ok(3 <= len(shots) <= 10, f"{s['attributes']['screenshotDisplayType']}: 3-10 screenshots", f"{len(shots)} uploaded")
            bad = [x["attributes"]["fileName"] for x in shots if x["attributes"].get("assetDeliveryState", {}).get("state") != "COMPLETE"]
            ok(not bad, "all screenshots finished processing", f"not complete: {bad}")
    rd = data(get(f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail"))
    if ok(bool(rd), "App Review contact details set", "none"):
        a = rd["attributes"]
        ok(bool(a.get("contactPhone")), "review contact phone set", "empty")
        ok((a.get("contactEmail") or "").endswith("@nelsongrey.com"), "review contact email is a nelsongrey.com address", f"got {a.get('contactEmail')}")
        ok(bool(a.get("notes")), "review notes written", "empty", warn_only=True)
        ok(a.get("demoAccountRequired") is False, "no demo account required", "demo account flagged required")
    build = data(get(f"/v1/appStoreVersions/{v['id']}/build"))
    ok(build is not None, "a build is attached to the version", "no build attached yet", warn_only=not require_attached)
    return v


def check_build() -> None:
    app_build = code_value("pubspec.yaml", r"^version: \d+\.\d+\.\d+\+(\d+)$").strip()
    builds = data(get(f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=5")) or []
    if not ok(bool(builds), "a build has been uploaded", "no builds in App Store Connect"):
        return
    latest = builds[0]["attributes"]
    record("INFO", "latest build", f"{latest['version']} {latest['processingState']}")
    ok(latest["processingState"] == "VALID", "latest build finished processing", latest["processingState"])
    ok(latest["version"] == app_build, "latest uploaded build matches pubspec", f"uploaded {latest['version']}, pubspec {app_build}", warn_only=True)
    ok(not latest["expired"], "latest build has not expired", "expired")


def check_price() -> None:
    sched = get(f"/v1/appPriceSchedules/{APP_ID}/manualPrices?include=appPricePoint")
    points = [i["attributes"]["customerPrice"] for i in sched.get("included", [])] if "error" not in sched else []
    ok(points == ["0.0"], "app is Free", f"price entries: {points}")
    av = data(get(f"/v1/apps/{APP_ID}/appAvailabilityV2"))
    if ok(bool(av), "availability is set", "no territory availability configured"):
        t = data(get(f"/v2/appAvailabilities/{av['id']}/territoryAvailabilities?limit=200")) or []
        ok(len(t) >= 100, "available in 100+ territories", f"{len(t)} territories", warn_only=True)


def check_iap() -> None:
    product = code_value("lib/app/app_services.dart", r"const adRemovalProductId = '([^']+)'")
    iaps = data(get(f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=50")) or []
    ok(len(iaps) == 1, "exactly one in-app purchase", f"{len(iaps)} found")
    iap = next((i for i in iaps if i["attributes"]["productId"] == product), None)
    if not ok(iap is not None, f"purchase {product} exists", f"products: {[i['attributes']['productId'] for i in iaps]}"):
        return
    a = iap["attributes"]
    ok(a["inAppPurchaseType"] == "NON_CONSUMABLE", "purchase is non-consumable", a["inAppPurchaseType"])
    ok(a["state"] in ("READY_TO_SUBMIT", "WAITING_FOR_REVIEW", "IN_REVIEW", "APPROVED"), "purchase is ready to submit", a["state"])
    iid = iap["id"]
    locs = data(get(f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations")) or []
    ok(any(l["attributes"]["name"] == EXPECTED_IAP_NAME for l in locs), f"purchase is displayed as {EXPECTED_IAP_NAME}", f"{[l['attributes']['name'] for l in locs]}")
    prices = get(f"/v1/inAppPurchasePriceSchedules/{iid}/manualPrices?include=inAppPurchasePricePoint")
    amounts = [i["attributes"]["customerPrice"] for i in prices.get("included", [])] if "error" not in prices else []
    ok(amounts == [EXPECTED_IAP_PRICE], f"purchase price is ${EXPECTED_IAP_PRICE}", f"price entries: {amounts}")
    ok(bool(data(get(f"/v2/inAppPurchases/{iid}/images"))), "purchase promotional image uploaded", "none")
    ok(bool(data(get(f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot"))), "purchase review screenshot uploaded", "none")


def check_game_center() -> None:
    ids = (MOBILE / "lib/gamecenter/game_center_ids.dart").read_text()
    leaderboard = re.search(r"leaderboardEndlessScore = '([^']+)'", ids).group(1)
    achievements = re.findall(r"achievement\w+\s*=\s*'([^']+)'", ids)
    gc = data(get(f"/v1/apps/{APP_ID}/gameCenterDetail"))
    if not ok(bool(gc), "Game Center is enabled for the app", "no gameCenterDetail"):
        return
    gid = gc["id"]
    boards = data(get(f"/v1/gameCenterDetails/{gid}/gameCenterLeaderboards?limit=50")) or []
    ok([b["attributes"]["vendorIdentifier"] for b in boards] == [leaderboard], "leaderboard ID matches the code", f"ASC: {[b['attributes']['vendorIdentifier'] for b in boards]}, code: {leaderboard}")
    for b in boards:
        loc = data(get(f"/v1/gameCenterLeaderboards/{b['id']}/localizations")) or []
        ok(bool(loc), "leaderboard has a localization (name, description, suffix)", "none")
        for l in loc:
            img = data(get(f"/v1/gameCenterLeaderboardLocalizations/{l['id']}/gameCenterLeaderboardImage"))
            ok(bool(img) and img["attributes"].get("assetDeliveryState", {}).get("state") == "COMPLETE", "leaderboard image uploaded", "missing or not processed")
    found = data(get(f"/v1/gameCenterDetails/{gid}/gameCenterAchievements?limit=50")) or []
    have = sorted(a["attributes"]["vendorIdentifier"] for a in found)
    ok(have == sorted(achievements), "achievement IDs match the code", f"ASC: {have}, code: {sorted(achievements)}")
    for a in found:
        loc = data(get(f"/v1/gameCenterAchievements/{a['id']}/localizations")) or []
        ok(bool(loc), f"{a['attributes']['vendorIdentifier']}: localized", "no localization")
        for l in loc:
            img = data(get(f"/v1/gameCenterAchievementLocalizations/{l['id']}/gameCenterAchievementImage"))
            ok(bool(img) and img["attributes"].get("assetDeliveryState", {}).get("state") == "COMPLETE", f"{a['attributes']['vendorIdentifier']}: image uploaded", "missing or not processed")


def main() -> int:
    global APP_ID
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--require-attached-build", action="store_true", help="FAIL (not WARN) when no build is attached to the version")
    args = p.parse_args()
    for var in ("APP_STORE_CONNECT_KEY", "APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID"):
        if not os.environ.get(var):
            sys.exit(f"{var} is not set")

    app = check_app()
    if app:
        APP_ID = app["id"]
        check_app_info(APP_ID)
        check_version(APP_ID, args.require_attached_build)
        check_build()
        check_price()
        check_iap()
        check_game_center()
    # Not readable through the API. Confirmed done by the owner on 2026-11-03:
    # App Privacy labels, EU trader status, AdMob consent message. Re-check them
    # in the consoles if the ad or data setup changes.
    record(
        "MANUAL",
        "App Privacy labels, EU trader status, AdMob consent message: owner confirmed done 2026-11-03",
    )

    width = max(len(c) for _, c, _ in results)
    for status, check, detail in results:
        print(f"{status:<6} {check:<{width}}  {detail}".rstrip())
    counts = {s: sum(1 for r in results if r[0] == s) for s in ("PASS", "WARN", "FAIL", "MANUAL")}
    print(f"\n{counts['PASS']} passed, {counts['WARN']} warnings, {counts['FAIL']} failed, {counts['MANUAL']} manual")
    return 1 if counts["FAIL"] else 0


APP_ID = ""

if __name__ == "__main__":
    sys.exit(main())
