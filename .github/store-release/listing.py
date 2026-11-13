#!/usr/bin/env python3
"""Turn an app's listing files into the metadata trees deliver and supply upload.

    listing.py OUT_DIR [ios] [android]

The store listing lives in one file per language, `listing/<code>.md` next to
store.yml (`en.md`, `de.md`, `it.md`, `pt-BR.md`):

    # German

    ## App Store

    **App Name** (30 characters):
    ```
    Cake Day: Geburtstage
    ```

    **Subtitle** (30 characters):
    ...

    ## Google Play

    **App Name** (30 characters):
    ...

A heading naming the App Store (or Apple) or Google Play starts that store's
fields; each field is a **Label** followed by a fenced block. What's New /
Release Notes are ignored on purpose: the release writes those, from the
changelog. A README.md in the folder is ignored too.

Writes OUT_DIR/ios/fastlane/metadata (deliver's layout, with store.yml's
copyright holder and the current year at the root) and OUT_DIR/android/metadata
(supply's layout), checks every field against the store's limits, and prints
what it wrote. Settings come from the environment, which config.rb fills from
store.yml: SR_LISTING_DIR, SR_LISTING_COPYRIGHT, SR_LISTING_SUPPORT_URL,
SR_LISTING_PRIVACY_URL, SR_LISTING_MARKETING_URL, SR_LISTING_LANGUAGES (lines
"code<TAB>app store locale<TAB>play locale", for what the table below lacks).
"""

import datetime
import os
import re
import sys

# A file's language code to the stores' locales. The two stores spell some
# differently (it / it-IT).
LOCALES = {
    "en": ("en-US", "en-US"),
    "en-GB": ("en-GB", "en-GB"),
    "de": ("de-DE", "de-DE"),
    "fr": ("fr-FR", "fr-FR"),
    "it": ("it", "it-IT"),
    "es": ("es-ES", "es-ES"),
    "pt": ("pt-PT", "pt-PT"),
    "pt-BR": ("pt-BR", "pt-BR"),
    "nl": ("nl-NL", "nl-NL"),
    "ru": ("ru", "ru-RU"),
    "pl": ("pl", "pl-PL"),
    "tr": ("tr", "tr-TR"),
    "sv": ("sv", "sv-SE"),
    "da": ("da", "da-DK"),
    "no": ("no", "no-NO"),
    "fi": ("fi", "fi-FI"),
    "cs": ("cs", "cs-CZ"),
    "ja": ("ja", "ja-JP"),
    "ko": ("ko", "ko-KR"),
    "zh-Hans": ("zh-Hans", "zh-CN"),
    "hi": ("hi", "hi-IN"),
}

# Label -> (file, character limit). Labels are matched case-insensitively.
APPLE = {
    "app name": ("name.txt", 30),
    "subtitle": ("subtitle.txt", 30),
    "keywords": ("keywords.txt", 100),
    "promotional text": ("promotional_text.txt", 170),
    "description": ("description.txt", 4000),
}
GOOGLE = {
    "app name": ("title.txt", 30),
    "short description": ("short_description.txt", 80),
    "full description": ("full_description.txt", 4000),
}
IGNORED = {"what's new", "whats new", "release notes"}

EMOJI = re.compile("[\U0001F000-\U0001FFFF☀-➿]")
OTHER_PLATFORM = re.compile(r"\b(android|google play|play store)\b", re.I)


def parse(text):
    """{"apple"|"google": {label: value}}"""
    stores, store, label, block, inside = {}, None, None, [], False
    for line in text.splitlines():
        if inside:
            if line.startswith("```"):
                inside = False
                if store and label:
                    stores.setdefault(store, {})[label] = "\n".join(block).strip()
                label = None
            else:
                block.append(line)
            continue
        m = re.match(r"^#+\s+(.+?)\s*$", line)
        if m:
            name = m.group(1).lower()
            if "app store" in name or name.startswith("apple"):
                store = "apple"
            elif "google" in name or "play" in name:
                store = "google"
            label = None
            continue
        m = re.match(r"^\*\*(.+?)\*\*", line)
        if m:
            label = m.group(1).strip().rstrip(":").lower()
            continue
        if line.startswith("```") and label:
            inside, block = True, []
    return stores


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: listing.py OUT_DIR [ios] [android]")
    out = sys.argv[1]
    wanted = set(sys.argv[2:]) or {"ios", "android"}
    env = os.environ
    folder = env.get("SR_LISTING_DIR") or "listing"
    if not os.path.isdir(folder):
        sys.exit(f"::error::No {folder}/: the store listing lives there, one file per language (store.yml listing.dir).")
    overrides = {}
    for raw in env.get("SR_LISTING_LANGUAGES", "").splitlines():
        if raw.strip():
            code, ios_locale, play_locale = (part.strip() for part in raw.split("\t"))
            overrides[code] = (ios_locale, play_locale)

    errors, warnings, wrote = [], [], {"ios": {}, "android": {}}

    def write(rel, value):
        full = os.path.join(out, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8") as f:
            f.write(value.strip() + "\n")

    files = sorted(f for f in os.listdir(folder) if f.endswith(".md") and not f.upper().startswith("README"))
    if not files:
        errors.append(f"{folder}/ has no <language>.md file.")
    for name in files:
        code = name[:-3]
        locales = overrides.get(code) or LOCALES.get(code)
        if not locales:
            errors.append(f"{folder}/{name}: '{code}' is no language code the listing knows. Add it to store.yml listing.languages with its App Store and Play locale.")
            continue
        stores = parse(open(os.path.join(folder, name), encoding="utf-8").read())
        if not stores:
            warnings.append(f"{folder}/{name} has no App Store or Google Play section.")
        for store, fields in stores.items():
            key = "ios" if store == "apple" else "android"
            if key not in wanted:
                continue
            table = APPLE if store == "apple" else GOOGLE
            locale = locales[0] if store == "apple" else locales[1]
            title = "App Store" if store == "apple" else "Play"
            for label, value in fields.items():
                if label in IGNORED:
                    continue
                if label not in table:
                    warnings.append(f"{folder}/{name}, {title}: '{label}' is not a listing field, left out.")
                    continue
                file, limit = table[label]
                where = f"{folder}/{name}, {title} {label}"
                if len(value) > limit:
                    errors.append(f"{where} has {len(value)} characters, the store takes {limit}.")
                if store == "apple" and EMOJI.search(value):
                    errors.append(f"{where} has an emoji, which App Store Connect refuses.")
                if store == "apple" and OTHER_PLATFORM.search(value):
                    warnings.append(f"{where} names Android or Google Play; App Review rejects listings that mention other platforms.")
                if store == "apple":
                    write(f"ios/fastlane/metadata/{locale}/{file}", value)
                else:
                    write(f"android/metadata/{locale}/{file}", value)
                wrote[key].setdefault(locale, []).append(file[:-4])
            if store == "apple":
                for field in ("support_url", "privacy_url", "marketing_url"):
                    url = env.get(f"SR_LISTING_{field.upper()}", "").strip()
                    if url:
                        write(f"ios/fastlane/metadata/{locale}/{field}.txt", url)
                        wrote["ios"].setdefault(locale, []).append(field)

    if "ios" in wanted and wrote["ios"]:
        holder = env.get("SR_LISTING_COPYRIGHT", "").strip()
        if holder:
            # Not localized, so at the root; precheck refuses any year but this one.
            write("ios/fastlane/metadata/copyright.txt", f"{datetime.date.today().year} {holder}")
            wrote["ios"]["(all)"] = ["copyright"]
        else:
            warnings.append("store.yml has no listing.copyright, so the App Store copyright is left as it is.")

    for w in warnings:
        print(f"::warning::{w}")
    if errors:
        for e in errors:
            print(f"::error::{e}")
        sys.exit(1)
    for key, title in (("ios", "App Store"), ("android", "Google Play")):
        if key in wanted:
            if not wrote[key]:
                print(f"::warning::{folder}/ has no {title} section, so nothing is sent there.")
            for locale, fields in sorted(wrote[key].items()):
                print(f"{title} {locale}: {', '.join(fields)}")


if __name__ == "__main__":
    main()
