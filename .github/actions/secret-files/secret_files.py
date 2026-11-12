"""Write an app's own secret files before a build, and take them away after.

Some secrets are read by the platform, not by Dart: a Maps SDK key in an
xcconfig that Info.plist resolves, or a line in android/local.properties that
build.gradle turns into a manifest value. --dart-define cannot reach those
files, and passing the value through a workflow input would put it in a
process listing. So the app keeps them in one secret, APP_SECRET_FILES_JSON:

    {"ios/Flutter/Secrets.xcconfig": "GOOGLE_MAPS_API_KEY=...\n",
     "android/local.properties": "GOOGLE_MAPS_API_KEY=..."}

Paths are relative to the app directory and must stay inside it.

* A *.properties path is merged key by key into whatever is there: Flutter
  owns local.properties (sdk paths, version name and code), creates it when it
  is missing and keeps keys it does not know. The file always ends with a
  newline, so an appended line never runs into the last one.
* Any other path is created and must not exist yet: these files are the ones
  .gitignore keeps out of the repo, and overwriting a committed file would
  hide a mistake.

Every value is masked in the log first (the part after "=" for key=value
lines). `clean` deletes what `write` created and restores a merged file, so a
reused runner keeps nothing.

    python3 secret_files.py write|clean     (DIR, FILES_JSON, MANIFEST in the environment)
"""

import json
import os
import re
import shutil
import sys

KEY_VALUE = re.compile(r"^\s*([A-Za-z_][\w.\-]*)\s*[=:]\s*(.*?)\s*$")
MIN_MASK = 6  # masking two-letter values would scramble the whole log


def fail(message):
    print(f"::error::{message}")
    sys.exit(1)


def mask(content):
    for line in content.splitlines():
        m = KEY_VALUE.match(line)
        part = (m.group(2) if m else line).strip()
        if len(part) >= MIN_MASK:
            print(f"::add-mask::{part}")


def inside(root, rel):
    if not rel or os.path.isabs(rel):
        fail(f"APP_SECRET_FILES_JSON: '{rel}' is not a path relative to the app directory.")
    path = os.path.realpath(os.path.join(root, rel))
    if not path.startswith(root + os.sep):
        fail(f"APP_SECRET_FILES_JSON: '{rel}' leaves the app directory.")
    return path


def merge_properties(path, content):
    wanted = {}
    for line in content.splitlines():
        m = KEY_VALUE.match(line)
        if m:
            wanted[m.group(1)] = m.group(2)
    if not wanted:
        fail(f"APP_SECRET_FILES_JSON: {os.path.basename(path)} has no key=value line to merge.")
    lines = []
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    done = set()
    for i, line in enumerate(lines):
        m = KEY_VALUE.match(line)
        if m and m.group(1) in wanted:
            lines[i] = f"{m.group(1)}={wanted[m.group(1)]}"
            done.add(m.group(1))
    lines += [f"{k}={v}" for k, v in wanted.items() if k not in done]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return sorted(wanted)


def write(root, manifest):
    raw = os.environ.get("FILES_JSON", "").strip()
    if not raw:
        print("No APP_SECRET_FILES_JSON, so there are no app secret files to write.")
        entries = []
    else:
        try:
            files = json.loads(raw)
        except ValueError:
            fail("APP_SECRET_FILES_JSON is not valid JSON.")  # never echo the value
        if not isinstance(files, dict) or not all(isinstance(v, str) for v in files.values()):
            fail('APP_SECRET_FILES_JSON is not an object of "path": "contents" strings.')
        for content in files.values():
            mask(content)
        entries = []
        backups = os.path.join(os.path.dirname(manifest), "secret-files-backup")
        for index, (rel, content) in enumerate(files.items()):
            path = inside(root, rel)
            existed = os.path.exists(path)
            if rel.endswith(".properties"):
                backup = None
                if existed:
                    os.makedirs(backups, exist_ok=True)
                    backup = os.path.join(backups, str(index))
                    shutil.copy2(path, backup)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                keys = merge_properties(path, content)
                entries.append({"path": path, "backup": backup})
                print(f"{rel}: merged {', '.join(keys)}")
            else:
                if existed:
                    fail(f"APP_SECRET_FILES_JSON: {rel} is already in the checkout. It writes only files the repo leaves out (a .properties file is merged instead).")
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content if content.endswith("\n") else content + "\n")
                os.chmod(path, 0o600)
                entries.append({"path": path, "backup": None})
                print(f"{rel}: written")
    with open(manifest, "w", encoding="utf-8") as f:
        json.dump(entries, f)


def clean(manifest):
    if not os.path.exists(manifest):
        return
    with open(manifest, encoding="utf-8") as f:
        entries = json.load(f)
    for entry in entries:
        if entry["backup"]:
            shutil.move(entry["backup"], entry["path"])
        elif os.path.exists(entry["path"]):
            os.remove(entry["path"])
    os.remove(manifest)
    if entries:
        print(f"Removed {len(entries)} app secret file(s).")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    root = os.path.realpath(os.environ.get("DIR") or ".")
    manifest = os.environ["MANIFEST"]
    if command == "write":
        write(root, manifest)
    elif command == "clean":
        clean(manifest)
    else:
        fail("usage: secret_files.py write|clean")


if __name__ == "__main__":
    main()
