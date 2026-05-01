#!/usr/bin/env python3
"""Parse METADATA.md and generate fastlane metadata files for iOS and Android."""

import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
METADATA_PATH = os.path.join(SCRIPT_DIR, "METADATA.md")

# Language config: display name -> (ios locale, android locale)
LANGUAGES = {
    "English": ("en-US", "en-US"),
}

# Field mappings: METADATA.md field name -> (ios filename, android filename)
IOS_FIELDS = {
    "App Name": "name.txt",
    "Subtitle": "subtitle.txt",
    "Keywords": "keywords.txt",
    "Promotional Text": "promotional_text.txt",
    "Description": "description.txt",
}

ANDROID_FIELDS = {
    "App Name": "title.txt",
    "Short Description": "short_description.txt",
    "Full Description": "full_description.txt",
}


def parse_metadata(content):
    """Parse METADATA.md into a nested dict: {language: {store: {field: value}}}."""
    result = {}
    current_lang = None
    current_store = None

    lines = content.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]

        # Language heading: ## English, ## German (Deutsch), etc.
        lang_match = re.match(r"^## (\w+)", line)
        if lang_match:
            current_lang = lang_match.group(1)
            if current_lang not in result:
                result[current_lang] = {}
            current_store = None
            i += 1
            continue

        # Store heading: ### Apple App Store, ### Google Play Store
        store_match = re.match(r"^### (Apple|Google)", line)
        if store_match:
            current_store = store_match.group(1)
            if current_lang and current_store not in result.get(current_lang, {}):
                result[current_lang][current_store] = {}
            i += 1
            continue

        # Field: **Field Name** (constraints):
        field_match = re.match(r"^\*\*(.+?)\*\*", line)
        if field_match and current_lang and current_store:
            field_name = field_match.group(1)
            # Look for code block on next lines
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                i += 1
            if i < len(lines) and lines[i].startswith("```"):
                i += 1  # skip opening ```
                value_lines = []
                while i < len(lines) and not lines[i].startswith("```"):
                    value_lines.append(lines[i])
                    i += 1
                value = "\n".join(value_lines).strip()
                result[current_lang][current_store][field_name] = value
            i += 1
            continue

        i += 1

    return result


def write_file(path, content):
    """Write content to file, creating directories as needed."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)
    print(f"  Wrote: {os.path.relpath(path, SCRIPT_DIR)}")


def main():
    if not os.path.exists(METADATA_PATH):
        print(f"Error: METADATA.md not found at {METADATA_PATH}", file=sys.stderr)
        sys.exit(1)

    with open(METADATA_PATH) as f:
        content = f.read()

    data = parse_metadata(content)

    for lang_name, (ios_locale, android_locale) in LANGUAGES.items():
        lang_data = data.get(lang_name, {})

        # iOS metadata
        apple_data = lang_data.get("Apple", {})
        if apple_data:
            ios_dir = os.path.join(SCRIPT_DIR, "ios", "fastlane", "metadata", ios_locale)
            for field, filename in IOS_FIELDS.items():
                if field in apple_data:
                    write_file(os.path.join(ios_dir, filename), apple_data[field])

        # Android metadata
        google_data = lang_data.get("Google", {})
        if google_data:
            android_dir = os.path.join(
                SCRIPT_DIR, "android", "fastlane", "metadata", "android", android_locale
            )
            for field, filename in ANDROID_FIELDS.items():
                if field in google_data:
                    write_file(os.path.join(android_dir, filename), google_data[field])

    # Copyright (iOS only) — year is prepended dynamically
    copyright_match = re.search(
        r"\*\*Copyright\*\*.*?\n```\n(.+?)\n```", content, re.DOTALL
    )
    if copyright_match:
        from datetime import datetime

        holder = copyright_match.group(1).strip()
        for _, (ios_locale, _) in LANGUAGES.items():
            ios_dir = os.path.join(SCRIPT_DIR, "ios", "fastlane", "metadata", ios_locale)
            write_file(
                os.path.join(ios_dir, "copyright.txt"),
                f"{datetime.now().year} {holder}",
            )

    print("Done!")


if __name__ == "__main__":
    main()
