#!/usr/bin/env bash
# Put one app's release credentials into its GitHub repo. ./release.sh setup
# runs it for the secrets an app is missing; tools/set-store-secrets.sh in
# ai-skills is the same script.
#
#   secrets.sh --repo owner/name [--file secrets.local.env] \
#       [--from-env app/.env] [--from-key-properties app/android/key.properties] \
#       [--dart-defines RC_APPLE_KEY,RC_GOOGLE_KEY] \
#       [--secret-file ios/Flutter/Secrets.xcconfig=app/ios/Flutter/Secrets.xcconfig] \
#       [--secret-file 'android/local.properties=app/android/local.properties#GOOGLE_MAPS_API_KEY'] \
#       [--only-missing]
#   secrets.sh --repo owner/name --check
#
#   --only-missing             leave every secret the environment already has
#                              as it is: CI may use other keys than this Mac
#                              (a separate App Store Connect key), and a
#                              re-run must not swap them
# An app that already releases by hand has most of this on disk, and the
# fewer hands a credential passes through the better, so the --from sources
# are read straight into the GitHub secret: nothing is copied into a file, a
# chat or a terminal on the way.
#
#   --from-env                 a fastlane .env: TEAM_ID, ASC_KEY_ID,
#                              ASC_ISSUER_ID, ASC_KEY_PATH
#   --from-key-properties      Flutter's key.properties: storeFile,
#                              storePassword, keyPassword, keyAlias
#   --file                     the rest, usually only the two values no repo
#                              has: the Apple distribution identity and the
#                              Play JSON key. APPLE_DISTRIBUTION_P12 may name
#                              a .p12 (with APPLE_DISTRIBUTION_P12_PASSWORD) or
#                              the bare private key (PEM, as kept in
#                              ~/.private_keys): then its certificate comes from
#                              the login keychain and the .p12 is built here,
#                              with a random password nobody needs to know
#   --dart-defines K1,K2       build-time values the app reads with
#                              String.fromEnvironment, taken by name from --file
#                              or --from-env and set as one DART_DEFINES_JSON
#                              secret (the workflows pass it to the Flutter build
#                              with --dart-define-from-file)
#   --secret-file REL=LOCAL    a file the platform reads at build time and the
#                              repo leaves out (an xcconfig with a Maps key):
#                              LOCAL's contents land at REL, relative to the
#                              app directory, before the build. For a
#                              .properties file name the keys to take,
#                              REL=LOCAL#KEY1,KEY2: a local.properties also
#                              holds this Mac's sdk.dir, which would break CI.
#                              Repeatable; all go into one APP_SECRET_FILES_JSON
#
# The App Review contact (APP_REVIEW_FIRST_NAME, _LAST_NAME, _EMAIL, _PHONE)
# comes from --file, or from a fastlane .env's ASC_REVIEW_* lines; the App
# Store job writes it to every new version, because Apple refuses a submission
# without one and does not copy it from the last version.
#
# A value in --file always wins; the --from sources only fill what is empty.
# Relative paths inside a --from file resolve against that file's directory,
# and an ASC key that is not where the .env says is looked for as
# AuthKey_<id>.p8 in the usual places.
#
# What it does for you: base64-encodes the .p8, .p12 and keystore, reads the
# team id out of the certificate and the upload-key SHA1 out of the keystore,
# refuses a .p12 with no private key, creates the environment, sets every
# secret through stdin (so no value reaches a process listing or the shell
# history), prints what it set without any value, and shreds --file.
#
# It never reads the active gh account implicitly: --repo is required and the
# account that will be used is printed and confirmed, because more than one
# account is logged in on this machine and the wrong one silently writes to
# the wrong org.
set -euo pipefail

REPO=""
FILE=""
FROM_ENV=""
FROM_KEY_PROPERTIES=""
DART_DEFINES=""
SECRET_FILES=()
ENVIRONMENT="production"
CHECK=false
KEEP=false
ASSUME_YES=false
ONLY_MISSING=false
EXISTING=""

die() { echo "error: $*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --file) FILE="${2:-}"; shift 2 ;;
    --from-env) FROM_ENV="${2:-}"; shift 2 ;;
    --from-key-properties) FROM_KEY_PROPERTIES="${2:-}"; shift 2 ;;
    --dart-defines) DART_DEFINES="${2:-}"; shift 2 ;;
    --secret-file) SECRET_FILES+=("${2:-}"); shift 2 ;;
    --env) ENVIRONMENT="${2:-}"; shift 2 ;;
    --check) CHECK=true; shift ;;
    --keep) KEEP=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --only-missing) ONLY_MISSING=true; shift ;;
    -h | --help) sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$REPO" ] || die "--repo owner/name is required."
command -v gh > /dev/null || die "gh is not installed."

echo "Repository: $REPO"
echo "Environment: $ENVIRONMENT"
gh api user --jq '"gh account: " + .login'
gh api "repos/$REPO" --jq '"  reachable as " + .full_name + " (" + (if .private then "private" else "public" end) + ")"' \
  || die "cannot see $REPO with this gh account. Switch with: gh auth switch"

# ───────────────────────────────── check ─────────────────────────────────
if [ "$CHECK" = true ]; then
  echo
  echo "Secrets on the $ENVIRONMENT environment:"
  gh secret list --repo "$REPO" --env "$ENVIRONMENT" 2> /dev/null || echo "  (no such environment yet)"
  echo "Repository variables:"
  gh variable list --repo "$REPO" 2> /dev/null || true
  exit 0
fi

if [ "$ONLY_MISSING" = true ]; then
  # Names only: GitHub never hands a value back.
  EXISTING=$(gh secret list --repo "$REPO" --env "$ENVIRONMENT" --json name --jq '.[].name' 2> /dev/null || true)
fi
present() { [ -n "$EXISTING" ] && printf '%s\n' "$EXISTING" | grep -qx "$1"; }

# Values are read, never sourced: a stray backtick in a password would
# otherwise run as code.
read_key() { # read_key FILE KEY
  [ -n "$1" ] && [ -f "$1" ] || return 0
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" | head -1 | sed 's/[[:space:]]*$//'
}
resolve() { # resolve BASEFILE PATH -> absolute, relative to the base file's dir
  local base path="$2"
  [ -n "$path" ] || return 0
  case "$path" in
    /*) printf '%s' "$path" ;;
    "~"*) printf '%s' "${path/#\~/$HOME}" ;;
    *) base="$(cd "$(dirname "$1")" && pwd)"; printf '%s/%s' "$base" "$path" ;;
  esac
}

if [ -n "$FILE" ] && [ ! -f "$FILE" ]; then
  die "$FILE does not exist. Copy shared/store-release/templates/secrets.local.env.example and fill it in."
fi
[ -n "$FILE" ] || [ -n "$FROM_ENV" ] || [ -n "$FROM_KEY_PROPERTIES" ] || [ ${#SECRET_FILES[@]} -gt 0 ] \
  || die "nothing to read: pass --file, the --from sources or --secret-file."
if [ -n "$DART_DEFINES" ] && [ -z "$FILE" ] && [ -z "$FROM_ENV" ]; then
  die "--dart-defines reads its values from --file or --from-env; pass one of them."
fi

# The build defines as one JSON object on stdout. Python reads the files
# itself, so no value ever reaches an argument list; --file wins over
# --from-env, like everywhere else here.
dart_defines_json() {
  python3 - "$DART_DEFINES" "$FILE" "$FROM_ENV" <<'PY'
import json, re, sys
keys = [k.strip() for k in sys.argv[1].split(",") if k.strip()]
values = {}
for path in (p for p in sys.argv[2:] if p):
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", line)
            if m and m.group(1) in keys and m.group(1) not in values and m.group(2):
                values[m.group(1)] = m.group(2)
missing = [k for k in keys if k not in values]
if missing:
    sys.exit("error: no value for the build define(s) " + ", ".join(missing))
json.dump(values, sys.stdout)
PY
}

# The app's secret files as one JSON object of path -> contents on stdout.
# Python reads the files itself, so no value reaches an argument list.
secret_files_json() {
  python3 - "${SECRET_FILES[@]}" <<'PY'
import json, re, sys
out = {}
for spec in sys.argv[1:]:
    rel, sep, local = spec.partition("=")
    local, _, keys = local.partition("#")
    rel, local = rel.strip(), local.strip()
    if not sep or not rel or not local:
        sys.exit(f"error: --secret-file wants REL=LOCAL, not '{spec}'")
    try:
        text = open(local, encoding="utf-8").read()
    except OSError as e:
        sys.exit(f"error: --secret-file {rel}: cannot read {local} ({e.strerror})")
    if rel.endswith(".properties"):
        wanted = [k.strip() for k in keys.split(",") if k.strip()]
        if not wanted:
            sys.exit(f"error: --secret-file {rel}: name the keys to take, {rel}={local}#KEY1,KEY2; a local.properties also holds this Mac's paths")
        found = {}
        for line in text.splitlines():
            m = re.match(r"\s*([A-Za-z_][\w.\-]*)\s*[=:]\s*(.*?)\s*$", line)
            if m and m.group(1) in wanted and m.group(2):
                found[m.group(1)] = m.group(2)
        missing = [k for k in wanted if k not in found]
        if missing:
            sys.exit(f"error: --secret-file {rel}: {local} has no value for " + ", ".join(missing))
        text = "".join(f"{k}={v}\n" for k, v in found.items())
    out[rel] = text
json.dump(out, sys.stdout)
PY
}
secret_files_summary() {
  local spec rel keys list=""
  # macOS's bash 3.2 calls an empty "${array[@]}" unbound under set -u.
  [ ${#SECRET_FILES[@]} -gt 0 ] || return 0
  for spec in "${SECRET_FILES[@]}"; do
    rel="${spec%%=*}" keys=""
    case "$spec" in *"#"*) keys=": ${spec#*#}" ;; esac
    list="${list:+$list, }$rel$keys"
  done
  printf '%s' "$list"
}

ASC_KEY_ID=$(read_key "$FILE" APP_STORE_CONNECT_API_KEY_ID)
ASC_ISSUER_ID=$(read_key "$FILE" APP_STORE_CONNECT_ISSUER_ID)
ASC_P8=$(read_key "$FILE" APP_STORE_CONNECT_API_KEY_P8)
P12=$(read_key "$FILE" APPLE_DISTRIBUTION_P12)
P12_PASSWORD=$(read_key "$FILE" APPLE_DISTRIBUTION_P12_PASSWORD)
TEAM_ID=$(read_key "$FILE" APPLE_TEAM_ID)
PLAY_JSON=$(read_key "$FILE" GOOGLE_PLAY_SERVICE_ACCOUNT_JSON)
KEYSTORE=$(read_key "$FILE" ANDROID_KEYSTORE)
KEYSTORE_PASSWORD=$(read_key "$FILE" ANDROID_KEYSTORE_PASSWORD)
KEY_PASSWORD=$(read_key "$FILE" ANDROID_KEY_PASSWORD)
KEY_ALIAS=$(read_key "$FILE" ANDROID_KEY_ALIAS)
UPLOAD_SHA1=$(read_key "$FILE" ANDROID_UPLOAD_KEY_SHA1)
REVIEW_FIRST_NAME=$(read_key "$FILE" APP_REVIEW_FIRST_NAME)
REVIEW_LAST_NAME=$(read_key "$FILE" APP_REVIEW_LAST_NAME)
REVIEW_EMAIL=$(read_key "$FILE" APP_REVIEW_EMAIL)
REVIEW_PHONE=$(read_key "$FILE" APP_REVIEW_PHONE)

if [ -n "$FROM_ENV" ]; then
  [ -f "$FROM_ENV" ] || die "--from-env $FROM_ENV does not exist."
  [ -n "$ASC_KEY_ID" ] || ASC_KEY_ID=$(read_key "$FROM_ENV" ASC_KEY_ID)
  [ -n "$ASC_ISSUER_ID" ] || ASC_ISSUER_ID=$(read_key "$FROM_ENV" ASC_ISSUER_ID)
  [ -n "$TEAM_ID" ] || TEAM_ID=$(read_key "$FROM_ENV" TEAM_ID)
  if [ -z "$ASC_P8" ]; then
    ASC_P8=$(resolve "$FROM_ENV" "$(read_key "$FROM_ENV" ASC_KEY_PATH)")
  fi
  note "from $(basename "$FROM_ENV"): the App Store Connect ids$([ -n "$ASC_P8" ] && echo " and the key path")"
  # fastlane's names for the App Review contact.
  [ -n "$REVIEW_FIRST_NAME" ] || REVIEW_FIRST_NAME=$(read_key "$FROM_ENV" ASC_REVIEW_FIRST_NAME)
  [ -n "$REVIEW_LAST_NAME" ] || REVIEW_LAST_NAME=$(read_key "$FROM_ENV" ASC_REVIEW_LAST_NAME)
  [ -n "$REVIEW_EMAIL" ] || REVIEW_EMAIL=$(read_key "$FROM_ENV" ASC_REVIEW_EMAIL)
  [ -n "$REVIEW_PHONE" ] || REVIEW_PHONE=$(read_key "$FROM_ENV" ASC_REVIEW_PHONE)
fi

if [ -n "$FROM_KEY_PROPERTIES" ]; then
  [ -f "$FROM_KEY_PROPERTIES" ] || die "--from-key-properties $FROM_KEY_PROPERTIES does not exist."
  [ -n "$KEYSTORE_PASSWORD" ] || KEYSTORE_PASSWORD=$(read_key "$FROM_KEY_PROPERTIES" storePassword)
  [ -n "$KEY_PASSWORD" ] || KEY_PASSWORD=$(read_key "$FROM_KEY_PROPERTIES" keyPassword)
  [ -n "$KEY_ALIAS" ] || KEY_ALIAS=$(read_key "$FROM_KEY_PROPERTIES" keyAlias)
  if [ -z "$KEYSTORE" ]; then
    KEYSTORE=$(resolve "$FROM_KEY_PROPERTIES" "$(read_key "$FROM_KEY_PROPERTIES" storeFile)")
  fi
  note "from $(basename "$FROM_KEY_PROPERTIES"): the keystore, its passwords and the alias"
fi

# An ASC key that is not where the .env claims: Apple names the file after the
# key id, so it can be found wherever it was left.
if [ -n "$ASC_KEY_ID" ] && { [ -z "$ASC_P8" ] || [ ! -f "$ASC_P8" ]; }; then
  for dir in "$HOME/.private_keys" "$HOME/Downloads/_keys" "$HOME/Downloads" "$HOME/.appstoreconnect/private_keys" \
    "$([ -n "$FROM_ENV" ] && dirname "$FROM_ENV" || echo .)"; do
    if [ -f "$dir/AuthKey_$ASC_KEY_ID.p8" ]; then
      ASC_P8="$dir/AuthKey_$ASC_KEY_ID.p8"
      note "found the API key as $ASC_P8"
      break
    fi
  done
fi

for pair in "APP_STORE_CONNECT_API_KEY_P8:$ASC_P8" "APPLE_DISTRIBUTION_P12:$P12" \
  "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:$PLAY_JSON" "ANDROID_KEYSTORE:$KEYSTORE"; do
  name="${pair%%:*}" path="${pair#*:}"
  if [ -n "$path" ] && [ ! -f "$path" ]; then
    die "$name points at $path, which does not exist."
  fi
done

# ─────────────────────────────── derive ───────────────────────────────
# OpenSSL 3 reads a Keychain Access export (RC2) only with -legacy, which
# LibreSSL does not know; try both.
p12() { openssl pkcs12 "$@" 2> /dev/null || openssl pkcs12 -legacy "$@" 2> /dev/null; }
# The bare private key instead of a .p12: what ~/.private_keys keeps, because
# a .p12 only bundles it with a certificate the keychain already has. Pair it
# with that certificate (the one whose public key matches) and build the .p12
# here, protected by a random password that goes straight into its secret.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
if [ -n "$P12" ] && grep -q -- "-----BEGIN .*PRIVATE KEY-----" "$P12" 2> /dev/null; then
  KEY_PUB=$(openssl pkey -in "$P12" -pubout 2> /dev/null | openssl sha256) \
    || die "$P12 looks like a private key, but openssl cannot read it (an encrypted key needs its passphrase removed first)."
  security find-certificate -a -c "Apple Distribution" -p > "$WORK/all.pem" 2> /dev/null || true
  awk -v dir="$WORK" '/-----BEGIN CERTIFICATE-----/ { n++ } n { print > (dir "/cert" n ".pem") }' "$WORK/all.pem"
  CERT=""
  for c in "$WORK"/cert*.pem; do
    [ -f "$c" ] || continue
    if [ "$(openssl x509 -in "$c" -noout -pubkey 2> /dev/null | openssl sha256)" = "$KEY_PUB" ] \
      && openssl x509 -in "$c" -noout -checkend 0 > /dev/null 2>&1; then
      CERT="$c"
      break
    fi
  done
  [ -n "$CERT" ] || die "No valid Apple Distribution certificate in the login keychain belongs to the key $P12. Download the certificate from developer.apple.com (Certificates) and open it, or export a .p12 from the Mac that has it (references/secrets.md)."
  note "certificate from the login keychain: $(openssl x509 -in "$CERT" -noout -subject 2> /dev/null | sed -n 's/.*CN[ ]*=[ ]*\([^,/]*\).*/\1/p'), until $(openssl x509 -in "$CERT" -noout -enddate | cut -d= -f2)"
  P12_PASSWORD=$(openssl rand -hex 24)
  # 3DES and a SHA-1 MAC, spelled out: the one encryption that LibreSSL,
  # OpenSSL 3 and macOS's security import all read without -legacy.
  ( umask 077; SR_P12_PASS="$P12_PASSWORD" openssl pkcs12 -export -inkey "$P12" -in "$CERT" \
      -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 \
      -name "$(openssl x509 -in "$CERT" -noout -subject | sed -n 's/.*CN[ ]*=[ ]*\([^,/]*\).*/\1/p')" \
      -out "$WORK/apple-distribution.p12" -passout env:SR_P12_PASS ) \
    || die "openssl could not build a .p12 from $P12 and its certificate."
  P12="$WORK/apple-distribution.p12"
  note "the .p12 was built from that certificate and the key, with a random password"
fi
# The .p12 and its password only work as a pair: a new one replaces both.
if [ -n "$P12" ]; then
  EXISTING=$(printf '%s\n' "$EXISTING" | grep -vxE 'APPLE_DISTRIBUTION_P12_B64|APPLE_DISTRIBUTION_P12_PASSWORD' || true)
fi

if [ -n "$P12" ] && [ -z "$TEAM_ID" ]; then
  # The team id is the OU of an Apple Distribution certificate.
  TEAM_ID=$(p12 -in "$P12" -nokeys -passin "pass:$P12_PASSWORD" \
    | openssl x509 -noout -subject 2> /dev/null \
    | tr ',/' '\n\n' | sed -n 's/.*OU[ ]*=[ ]*//p' | head -1 || true)
  if [ -n "$TEAM_ID" ]; then
    note "team id from the certificate: $TEAM_ID"
  else
    note "could not read the team id from the certificate; store.yml ios.team_id has it anyway"
  fi
fi

if [ -n "$KEYSTORE" ] && [ -z "$UPLOAD_SHA1" ]; then
  UPLOAD_SHA1=$(keytool -list -v -keystore "$KEYSTORE" -storepass "$KEYSTORE_PASSWORD" 2> /dev/null \
    | grep -m1 'SHA1:' | tr -d ' ' | cut -d: -f2- || true)
  [ -n "$UPLOAD_SHA1" ] && note "upload key SHA1 from the keystore: $UPLOAD_SHA1"
fi

if [ -n "$P12" ]; then
  # Catch the mistake that costs a whole iOS release: a .p12 exported without
  # its private key signs nothing, and the error comes much later.
  if ! p12 -in "$P12" -nocerts -passin "pass:$P12_PASSWORD" -passout pass:x > /dev/null; then
    if ! p12 -in "$P12" -info -noout -passin "pass:$P12_PASSWORD" > /dev/null \
      && ! p12 -in "$P12" -info -noout -passin pass:x > /dev/null \
      && [ "$(file -b "$P12" | cut -d' ' -f1)" != data ]; then
      die "$P12 is no .p12 ($(file -b "$P12")). Give the .p12, or the bare private key it was built from (references/secrets.md)."
    fi
    die "$P12 has no private key, or the password is wrong. Export the certificate AND its key from Keychain Access, or give the bare private key instead (references/secrets.md)."
  fi
  note "the certificate carries its private key"
fi

if [ -n "$DART_DEFINES" ]; then
  dart_defines_json > /dev/null || exit 1
  note "build defines found: $DART_DEFINES"
fi

if [ ${#SECRET_FILES[@]} -gt 0 ]; then
  secret_files_json > /dev/null || exit 1
  note "app secret files found: $(secret_files_summary)"
fi

if [ -n "$PLAY_JSON" ]; then
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["type"]=="service_account"; print("  play service account: " + d["client_email"])' "$PLAY_JSON" \
    || die "$PLAY_JSON is not a service-account key JSON."
fi

echo
echo "Will set:"
for pair in "APP_STORE_CONNECT_API_KEY_ID:$ASC_KEY_ID" "APP_STORE_CONNECT_ISSUER_ID:$ASC_ISSUER_ID" \
  "APP_STORE_CONNECT_API_KEY_P8_B64:$ASC_P8" "APPLE_DISTRIBUTION_P12_B64:$P12" \
  "APPLE_DISTRIBUTION_P12_PASSWORD:$P12_PASSWORD" "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:$PLAY_JSON" \
  "ANDROID_KEYSTORE_B64:$KEYSTORE" "ANDROID_KEYSTORE_PASSWORD:$KEYSTORE_PASSWORD" \
  "ANDROID_KEY_PASSWORD:$KEY_PASSWORD" "ANDROID_UPLOAD_KEY_SHA1:$UPLOAD_SHA1" \
  "DART_DEFINES_JSON ($DART_DEFINES):$DART_DEFINES" \
  "APP_SECRET_FILES_JSON ($(secret_files_summary)):$(secret_files_summary)" \
  "APP_REVIEW_FIRST_NAME:$REVIEW_FIRST_NAME" "APP_REVIEW_LAST_NAME:$REVIEW_LAST_NAME" \
  "APP_REVIEW_EMAIL:$REVIEW_EMAIL" "APP_REVIEW_PHONE:$REVIEW_PHONE"; do
  name="${pair%%:*}" value="${pair#*:}"
  if present "${name%% *}"; then
    note "$name: already set, kept"
  elif [ -n "$value" ]; then
    note "$name"
  else
    note "$name: SKIPPED, no value"
  fi
done

if [ "$ASSUME_YES" != true ]; then
  printf 'Write these to %s (%s environment)? [y/N] ' "$REPO" "$ENVIRONMENT"
  read -r answer
  case "$answer" in y | Y | yes) ;; *) die "nothing was written." ;; esac
fi

# ──────────────────────────────── write ────────────────────────────────
gh api -X PUT "repos/$REPO/environments/$ENVIRONMENT" --silent
note "environment $ENVIRONMENT exists"

set_secret() { # set_secret NAME VALUE
  [ -n "$2" ] || return 0
  present "$1" && return 0
  printf '%s' "$2" | gh secret set "$1" --repo "$REPO" --env "$ENVIRONMENT" > /dev/null
  note "secret $1"
}
set_secret_b64() { # set_secret_b64 NAME FILE
  [ -n "$2" ] || return 0
  present "$1" && return 0
  base64 < "$2" | tr -d '\n' | gh secret set "$1" --repo "$REPO" --env "$ENVIRONMENT" > /dev/null
  note "secret $1 (base64 of $(basename "$2"))"
}
set_secret_file() { # set_secret_file NAME FILE — contents verbatim, through stdin
  [ -n "$2" ] || return 0
  present "$1" && return 0
  gh secret set "$1" --repo "$REPO" --env "$ENVIRONMENT" < "$2" > /dev/null
  note "secret $1 (contents of $(basename "$2"))"
}

set_secret APP_STORE_CONNECT_API_KEY_ID "$ASC_KEY_ID"
set_secret APP_STORE_CONNECT_ISSUER_ID "$ASC_ISSUER_ID"
set_secret_b64 APP_STORE_CONNECT_API_KEY_P8_B64 "$ASC_P8"
set_secret_b64 APPLE_DISTRIBUTION_P12_B64 "$P12"
set_secret APPLE_DISTRIBUTION_P12_PASSWORD "$P12_PASSWORD"
set_secret_file GOOGLE_PLAY_SERVICE_ACCOUNT_JSON "$PLAY_JSON"
set_secret_b64 ANDROID_KEYSTORE_B64 "$KEYSTORE"
set_secret ANDROID_KEYSTORE_PASSWORD "$KEYSTORE_PASSWORD"
set_secret ANDROID_KEY_PASSWORD "$KEY_PASSWORD"
set_secret ANDROID_UPLOAD_KEY_SHA1 "$UPLOAD_SHA1"
if [ -n "$DART_DEFINES" ] && ! present DART_DEFINES_JSON; then
  dart_defines_json | gh secret set DART_DEFINES_JSON --repo "$REPO" --env "$ENVIRONMENT" > /dev/null
  note "secret DART_DEFINES_JSON ($DART_DEFINES)"
fi
if [ ${#SECRET_FILES[@]} -gt 0 ] && ! present APP_SECRET_FILES_JSON; then
  secret_files_json | gh secret set APP_SECRET_FILES_JSON --repo "$REPO" --env "$ENVIRONMENT" > /dev/null
  note "secret APP_SECRET_FILES_JSON ($(secret_files_summary))"
fi
set_secret APP_REVIEW_FIRST_NAME "$REVIEW_FIRST_NAME"
set_secret APP_REVIEW_LAST_NAME "$REVIEW_LAST_NAME"
set_secret APP_REVIEW_EMAIL "$REVIEW_EMAIL"
set_secret APP_REVIEW_PHONE "$REVIEW_PHONE"
# Not secret, so they belong in store.yml (ios.team_id, android.key_alias),
# which is what the pipeline reads.
[ -n "$TEAM_ID" ] && note "store.yml ios.team_id should be $TEAM_ID"
[ -n "${KEY_ALIAS:-}" ] && note "store.yml android.key_alias should be $KEY_ALIAS"

echo
echo "On $REPO now:"
gh secret list --repo "$REPO" --env "$ENVIRONMENT"

if [ -n "$FILE" ] && [ "$KEEP" != true ]; then
  rm -P "$FILE" 2> /dev/null || rm -f "$FILE"
  echo
  echo "$FILE shredded. The originals (.p8, .p12, keystore, play key) stay where they are — keep them in your password manager, not in a repo."
fi
