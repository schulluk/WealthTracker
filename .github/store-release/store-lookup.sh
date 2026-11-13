#!/usr/bin/env bash
# Print the defaults ./release.sh setup offers when it fills in an app's
# store.yml: what the stores say about the app now, and where they say nothing
# yet (a new app, or one that is in only one store), what the other apps on
# the account use and which languages the app itself ships. Read only:
# nothing in either console changes (the Play side opens a draft edit to read
# it and deletes it again).
#
#   store-lookup.sh --from-env app/.env --bundle-id ch.example.app \
#       [--package ch.example.app --play-key app/android/fastlane/play-store-key.json] \
#       [--project app]
#
#   --from-env     a .env with ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
#                  (relative paths resolve against the .env's directory). The
#                  key is team-wide, so a new app without a .env of its own
#                  can use another app's.
#   --bundle-id    the App Store app (leave out, with --from-env, for an app
#                  only on Google Play)
#   --package      the Play app (optional)
#   --play-key     the Play service-account JSON (optional, with --package)
#   --project      the Flutter app directory, for the languages it ships
#                  (l10n.yaml's arb files, else the iOS knownRegions)
#
# With SD_LISTING_JSON=FILE it also writes the current store listing there,
# as {"app_store": {locale: {name, subtitle, keywords, promotional_text,
# description, support_url, marketing_url, privacy_url}}, "play": {locale:
# {title, short_description, full_description}}}, which listing.py
# --from-json turns into listing/<language>.md.
#
# Prints, as YAML ready to offer item by item:
#   app_review          the App Review contact on the app's newest App Store
#                       version that has one
#   app_review_options  only when the app has none yet: the contact each other
#                       app on the account uses, for Lukas to pick from. Never
#                       a silent default: the contact differs per app.
#   app_store           the newest version's number and localizations (every
#                       locale store.yml needs a What's New line for), or the
#                       status "not in App Store Connect yet" / "no version yet"
#   urls                support, marketing and privacy URL of the listing's
#                       English (else first) localization
#   play                the listing's contact email, phone, website and
#                       languages, or "not in Play Console yet"
#   app_languages       the languages the app ships, with the store locale for
#                       each: the locale list for a store that has none yet
#
# These are contact details, not credentials, so they may be shown in the
# chat: the point is to ask "keep this?" with a value already filled in.
# Runs the lookups through fastlane, so it needs nothing but fastlane.
set -euo pipefail

FROM_ENV="" BUNDLE_ID="" PACKAGE="" PLAY_KEY="" PROJECT=""
die() { echo "error: $*" >&2; exit 1; }
while [ $# -gt 0 ]; do
  case "$1" in
    --from-env) FROM_ENV="${2:-}"; shift 2 ;;
    --bundle-id) BUNDLE_ID="${2:-}"; shift 2 ;;
    --package) PACKAGE="${2:-}"; shift 2 ;;
    --play-key) PLAY_KEY="${2:-}"; shift 2 ;;
    --project) PROJECT="${2:-}"; shift 2 ;;
    -h | --help) sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$BUNDLE_ID$PACKAGE" ] || die "--bundle-id or --package is required."
[ -z "$BUNDLE_ID" ] || { [ -n "$FROM_ENV" ] && [ -f "$FROM_ENV" ]; } \
  || die "--from-env must name a .env with the App Store Connect key (any app's on the same team will do)."
[ -z "$PACKAGE" ] || [ -f "$PLAY_KEY" ] || die "--package needs --play-key with the service-account JSON."
[ -z "$PROJECT" ] || [ -d "$PROJECT" ] || die "--project must be the app directory."
command -v fastlane > /dev/null || die "fastlane is not installed."
absolute() { printf '%s/%s' "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"; }
[ -z "$FROM_ENV" ] || FROM_ENV=$(absolute "$FROM_ENV")
LISTING_JSON="${SD_LISTING_JSON:-}"
[ -z "$LISTING_JSON" ] || LISTING_JSON=$(absolute "$LISTING_JSON")
[ -z "$PLAY_KEY" ] || PLAY_KEY=$(absolute "$PLAY_KEY")
[ -z "$PROJECT" ] || PROJECT=$(cd "$PROJECT" && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/fastlane"
# A throwaway Fastfile: fastlane brings Spaceship and Google's client with it,
# so this works wherever fastlane does. Values reach Ruby through the
# environment, never the command line.
cat > "$WORK/fastlane/Fastfile" <<'RUBY'
require "json"
require "yaml"

# The store locale for a language the app ships. The stores spell some
# differently (it / it-IT); a language missing here is printed as it is.
ASC_LOCALE = {
  "en" => "en-US", "de" => "de-DE", "fr" => "fr-FR", "es" => "es-ES", "it" => "it",
  "nl" => "nl-NL", "pt" => "pt-BR", "ja" => "ja", "ko" => "ko", "zh" => "zh-Hans",
  "ru" => "ru", "pl" => "pl", "tr" => "tr", "sv" => "sv", "da" => "da", "fi" => "fi",
  "nb" => "no", "no" => "no", "cs" => "cs"
}.freeze
PLAY_LOCALE = {
  "en" => "en-US", "de" => "de-DE", "fr" => "fr-FR", "es" => "es-ES", "it" => "it-IT",
  "nl" => "nl-NL", "pt" => "pt-BR", "ja" => "ja-JP", "ko" => "ko-KR", "zh" => "zh-CN",
  "ru" => "ru-RU", "pl" => "pl-PL", "tr" => "tr-TR", "sv" => "sv-SE", "da" => "da-DK",
  "fi" => "fi-FI", "nb" => "no-NO", "no" => "no-NO", "cs" => "cs-CZ"
}.freeze

def contact_of(version)
  d = (version.fetch_app_store_review_detail rescue nil)
  return nil if d.nil? || d.contact_email.to_s.empty?
  { "first_name" => d.contact_first_name, "last_name" => d.contact_last_name,
    "email" => d.contact_email, "phone" => d.contact_phone }
end

def ios_versions(app)
  app.get_app_store_versions(filter: { platform: "IOS" }).sort_by { |v| v.created_date.to_s }.reverse
end

# The languages the app ships: gen-l10n's arb files, else the iOS project's
# knownRegions.
def app_languages(dir)
  langs = []
  l10n = File.join(dir, "l10n.yaml")
  arb_dir = File.join(dir, (File.exist?(l10n) && (YAML.safe_load(File.read(l10n)) || {})["arb-dir"]) || "lib/l10n")
  Dir.glob(File.join(arb_dir, "*.arb")).sort.each do |f|
    locale = (JSON.parse(File.read(f))["@@locale"] rescue nil)
    locale ||= File.basename(f, ".arb")[/_([a-z]{2,3}(?:_[A-Za-z]{2,4})?)\z/, 1]
    langs << locale if locale
  end
  source = "#{File.basename(arb_dir)}/*.arb"
  if langs.empty?
    pbx = File.join(dir, "ios/Runner.xcodeproj/project.pbxproj")
    if File.exist?(pbx) && (list = File.read(pbx)[/knownRegions = \((.*?)\);/m, 1])
      langs = list.split(",").map { |s| s.strip.delete('"') }.reject { |s| s.empty? || s == "Base" }
      source = "iOS knownRegions"
    end
  end
  return nil if langs.empty?
  {
    "from" => source,
    "locales" => langs.uniq.map do |l|
      base = l.split(/[_-]/).first
      { "language" => l, "app_store" => ASC_LOCALE.fetch(base, l), "play" => PLAY_LOCALE.fetch(base, l) }
    end
  }
end

# The listing of the newest version: its texts and URLs, keyed by locale.
def app_store_listing(app, version)
  by = {}
  version.get_app_store_version_localizations.each do |l|
    by[l.locale] = { "description" => l.description, "keywords" => l.keywords,
                     "promotional_text" => l.promotional_text, "support_url" => l.support_url,
                     "marketing_url" => l.marketing_url }
  end
  info = (app.fetch_edit_app_info rescue nil) || (app.fetch_live_app_info rescue nil)
  (info ? info.get_app_info_localizations : []).each do |l|
    (by[l.locale] ||= {}).merge!("name" => l.name, "subtitle" => l.subtitle, "privacy_url" => l.privacy_policy_url)
  end
  by
end

lane :store_defaults do
  out = {}
  dump = {}
  bundle_id = ENV["SD_BUNDLE_ID"].to_s
  unless bundle_id.empty?
    env = {}
    File.foreach(ENV.fetch("SD_FROM_ENV")) do |line|
      next unless line.chomp =~ /\A\s*([A-Z_]+)\s*=\s*(.*?)\s*\z/
      env[$1] = $2.delete_prefix('"').delete_suffix('"')
    end
    key_path = File.expand_path(env.fetch("ASC_KEY_PATH"), File.dirname(ENV.fetch("SD_FROM_ENV")))
    Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
      key_id: env.fetch("ASC_KEY_ID"), issuer_id: env.fetch("ASC_ISSUER_ID"), filepath: key_path
    )
    app = Spaceship::ConnectAPI::App.find(bundle_id)
    versions = app ? ios_versions(app) : []
    own = versions.lazy.map { |v| (c = contact_of(v)) && { "from" => "App Store #{v.version_string}" }.merge(c) }.find(&:itself)
    if own
      out["app_review"] = own
    else
      # Nothing to keep yet, so offer what the other apps use, each with its
      # source. Lukas picks; the contact differs per app.
      options = Spaceship::ConnectAPI::App.all.reject { |a| a.bundle_id == bundle_id }.filter_map do |other|
        v = ios_versions(other).find { |x| contact_of(x) }
        v && { "from" => "App Store #{other.name} #{v.version_string}" }.merge(contact_of(v))
      end
      out["app_review_options"] = options.uniq { |o| [o["email"], o["phone"], o["first_name"], o["last_name"]] }
    end
    out["app_store"] =
      if app.nil? then { "status" => "not in App Store Connect yet" }
      elsif versions.empty? then { "status" => "no App Store version yet" }
      else
        listing = app_store_listing(app, versions.first)
        dump["app_store"] = listing
        main = listing["en-US"] || listing.values.first || {}
        out["urls"] = { "support_url" => main["support_url"], "marketing_url" => main["marketing_url"],
                        "privacy_url" => main["privacy_url"] }.reject { |_, v| v.to_s.empty? }
        { "from" => "App Store #{versions.first.version_string}", "version" => versions.first.version_string,
          "locales" => listing.keys.sort }
      end
  end

  if (package = ENV["SD_PACKAGE"].to_s) != ""
    require "googleauth"
    require "google/apis/androidpublisher_v3"
    play = Google::Apis::AndroidpublisherV3::AndroidPublisherService.new
    play.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(ENV.fetch("SD_PLAY_KEY")),
      scope: "https://www.googleapis.com/auth/androidpublisher"
    )
    begin
      edit = play.insert_edit(package)
    rescue Google::Apis::ClientError => e
      raise unless e.status_code == 404 || e.message =~ /not ?found/i
      out["play"] = { "status" => "not in Play Console yet" }
    end
    if edit
      begin
        details = play.get_edit_detail(package, edit.id)
        listings = play.list_edit_listings(package, edit.id).listings || []
        out["play"] = {
          "contact_email" => details.contact_email, "contact_phone" => details.contact_phone,
          "contact_website" => details.contact_website, "default_language" => details.default_language,
          "locales" => listings.map(&:language).sort
        }
        dump["play"] = listings.map do |l|
          [l.language, { "title" => l.title, "short_description" => l.short_description,
                         "full_description" => l.full_description }]
        end.to_h
      ensure
        play.delete_edit(package, edit.id) # a draft edit only; nothing was changed
      end
    end
  end

  if (dir = ENV["SD_PROJECT"].to_s) != "" && (langs = app_languages(dir))
    out["app_languages"] = langs
  end
  File.write(ENV["SD_LISTING_JSON"], JSON.pretty_generate(dump)) unless ENV["SD_LISTING_JSON"].to_s.empty?
  puts "--- store defaults ---"
  puts out.to_yaml.sub(/\A---\n/, "")
end
RUBY

cd "$WORK"
if ! SD_FROM_ENV="$FROM_ENV" SD_BUNDLE_ID="$BUNDLE_ID" SD_PACKAGE="$PACKAGE" SD_PLAY_KEY="$PLAY_KEY" SD_PROJECT="$PROJECT" \
  SD_LISTING_JSON="$LISTING_JSON" \
  FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_TIMESTAMP=1 FASTLANE_DISABLE_COLORS=1 \
  fastlane store_defaults > "$WORK/log" 2>&1; then
  grep -v '^\s*$' "$WORK/log" | tail -15 >&2
  die "the store lookup failed (fastlane's last lines above)."
fi
sed -n '/^--- store defaults ---$/,$p' "$WORK/log" | sed '1d' | sed '/^\[/d;/fastlane.tools/,$d'
