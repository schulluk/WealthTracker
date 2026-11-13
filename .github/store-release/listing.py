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
changelog. A README.md in the folder is ignored too. The support, privacy
and marketing URLs come from store.yml for every language; a language whose
URL differs (a privacy policy in German) gets a **Support URL**, **Privacy
URL** or **Marketing URL** field in its App Store section, which wins there.

Writes OUT_DIR/ios/fastlane/metadata (deliver's layout, with store.yml's
copyright holder and the current year at the root) and OUT_DIR/android/metadata
(supply's layout), checks every field against the store's limits, and prints
what it wrote. An empty field is left out, so the store keeps what it has.
Settings come from the environment, which config.rb fills from store.yml:
SR_LISTING_DIR, SR_LISTING_COPYRIGHT, SR_LISTING_SUPPORT_URL,
SR_LISTING_PRIVACY_URL, SR_LISTING_MARKETING_URL, SR_LISTING_LANGUAGES (lines
"code<TAB>app store locale<TAB>play locale", for what the table below lacks).

    listing.py --from-json LISTING_JSON OUT_DIR

goes the other way, for ./release.sh setup: the listing as the stores have it
now (store-lookup.sh's SD_LISTING_JSON) becomes OUT_DIR/<code>.md, one file
per language, never replacing a file that is there. A locale the table lacks
is printed as "language<TAB>code<TAB>app store locale<TAB>play locale", for
store.yml's listing.languages.
"""

import datetime
import json
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
# A language whose URL differs from store.yml's (a privacy policy in German)
# carries its own in the App Store section; store.yml's covers the rest.
URLS = {
    "support url": "support_url",
    "privacy url": "privacy_url",
    "privacy policy url": "privacy_url",
    "marketing url": "marketing_url",
}
GOOGLE = {
    "app name": ("title.txt", 30),
    "short description": ("short_description.txt", 80),
    "full description": ("full_description.txt", 4000),
}
IGNORED = {"what's new", "whats new", "release notes"}

# For the heading of a file --from-json writes.
NAMES = {
    "en": "English", "en-GB": "English (UK)", "de": "German", "fr": "French", "it": "Italian",
    "es": "Spanish", "pt": "Portuguese", "pt-BR": "Portuguese, Brazil", "nl": "Dutch",
    "ru": "Russian", "pl": "Polish", "tr": "Turkish", "sv": "Swedish", "da": "Danish",
    "no": "Norwegian", "fi": "Finnish", "cs": "Czech", "ja": "Japanese", "ko": "Korean",
    "zh-Hans": "Chinese, Simplified", "hi": "Hindi",
}
# The store's field name, in the order a listing file shows them.
IMPORT = {
    "apple": [("App Name", "name"), ("Subtitle", "subtitle"), ("Keywords", "keywords"),
              ("Promotional Text", "promotional_text"), ("Description", "description")],
    # Written only where the language's URL is not store.yml's.
    "apple_urls": [("Support URL", "support_url"), ("Privacy URL", "privacy_url"),
                   ("Marketing URL", "marketing_url")],
    "google": [("App Name", "title"), ("Short Description", "short_description"),
               ("Full Description", "full_description")],
}

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


def language_table():
    """LOCALES with store.yml's listing.languages on top."""
    table = dict(LOCALES)
    for raw in os.environ.get("SR_LISTING_LANGUAGES", "").splitlines():
        if raw.strip():
            code, ios_locale, play_locale = (part.strip() for part in raw.split("\t"))
            table[code] = (ios_locale, play_locale)
    return table


def from_json(src, folder):
    data = json.load(open(src, encoding="utf-8"))
    table = language_table()
    by_store = {
        "apple": {apple: code for code, (apple, _) in table.items()},
        "google": {play: code for code, (_, play) in table.items()},
    }
    files, unknown = {}, {}
    for store, key in (("apple", "app_store"), ("google", "play")):
        for locale, fields in sorted((data.get(key) or {}).items()):
            code = by_store[store].get(locale, locale)
            if code not in table:
                pair = unknown.setdefault(code, [locale, locale])
                pair[0 if store == "apple" else 1] = locale
            files.setdefault(code, {})[store] = fields or {}
    os.makedirs(folder, exist_ok=True)
    for code in sorted(files):
        path = os.path.join(folder, f"{code}.md")
        if os.path.exists(path):
            print(f"  {path}: there already, left as it is")
            continue
        lines = [f"# {NAMES.get(code, code)}", ""]
        for store, heading in (("apple", "App Store"), ("google", "Google Play")):
            if store not in files[code]:
                continue
            limits = APPLE if store == "apple" else GOOGLE
            lines += [f"## {heading}", ""]
            for label, field in IMPORT[store]:
                value = (files[code][store].get(field) or "").strip()
                lines += [f"**{label}** ({limits[label.lower()][1]} characters):", "```", value, "```", ""]
            if store == "apple":
                # Only a URL that is not store.yml's: the rest stays there.
                for label, field in IMPORT["apple_urls"]:
                    value = (files[code][store].get(field) or "").strip()
                    if value and value != os.environ.get(f"SR_LISTING_{field.upper()}", "").strip():
                        lines += [f"**{label}** (this language only; store.yml has the others):", "```", value, "```", ""]
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines).rstrip() + "\n")
        stores = " and ".join(h for s, h in (("apple", "App Store"), ("google", "Google Play")) if s in files[code])
        print(f"  {path}: {stores}")
    for code, (apple, play) in sorted(unknown.items()):
        print(f"language\t{code}\t{apple}\t{play}")


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--from-json":
        from_json(sys.argv[2], sys.argv[3])
        return
    if sys.argv[1:] == ["--locales"]:
        # For setup.rb: language code -> [App Store locale, Play locale].
        print(json.dumps(language_table()))
        return
    if len(sys.argv) < 2:
        sys.exit("usage: listing.py OUT_DIR [ios] [android] | listing.py --from-json LISTING_JSON OUT_DIR")
    out = sys.argv[1]
    wanted = set(sys.argv[2:]) or {"ios", "android"}
    env = os.environ
    folder = env.get("SR_LISTING_DIR") or "listing"
    if not os.path.isdir(folder):
        sys.exit(f"::error::No {folder}/: the store listing lives there, one file per language (store.yml listing.dir).")
    table = language_table()

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
        locales = table.get(code)
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
            fields_table = APPLE if store == "apple" else GOOGLE
            locale = locales[0] if store == "apple" else locales[1]
            title = "App Store" if store == "apple" else "Play"
            empty, own_urls = [], set()
            for label, value in fields.items():
                if label in IGNORED:
                    continue
                if store == "apple" and label in URLS:
                    if value and not re.match(r"https?://\S+$", value):
                        errors.append(f"{folder}/{name}, {title} {label}: '{value}' is not a URL.")
                    elif value:
                        write(f"ios/fastlane/metadata/{locale}/{URLS[label]}.txt", value)
                        own_urls.add(URLS[label])
                        wrote[key].setdefault(locale, []).append(URLS[label])
                    continue
                if label not in fields_table:
                    warnings.append(f"{folder}/{name}, {title}: '{label}' is not a listing field, left out.")
                    continue
                if not value:
                    empty.append(label)
                    continue
                file, limit = fields_table[label]
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
            if empty:
                warnings.append(f"{folder}/{name}, {title}: {', '.join(empty)} empty, so the store keeps what it has.")
            if store == "apple":
                for field in ("support_url", "privacy_url", "marketing_url"):
                    url = env.get(f"SR_LISTING_{field.upper()}", "").strip()
                    if url and field not in own_urls:
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
