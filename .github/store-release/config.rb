# frozen_string_literal: true

# How an app is built and released, read from its store.yml: the one place
# both the GitHub workflows and release.sh --local take it from, so the two
# can never disagree about an id, a toolchain version or a build command.
#
#   ruby config.rb locate            the store.yml this repo uses
#   ruby config.rb shell             `export SR_...=...` lines for eval
#   ruby config.rb github            the same as GitHub step outputs
#   ruby config.rb check             validate, print nothing on success
#
# store.yml is found at the repository root or one directory below it
# (app/store.yml); STORE_FILE overrides that. Every path in it is relative to
# the app directory, which is store.yml's own directory unless app.dir says
# otherwise. Ruby 2.6 compatible: it also runs on macOS's system Ruby.

require "yaml"
require "shellwords"

module StoreConfig
  module_function

  class Error < StandardError; end

  STACKS = { "ios" => %w[flutter ios-xcode], "android" => %w[flutter android-gradle] }.freeze

  def root
    @root ||= begin
      out = `git rev-parse --show-toplevel 2>/dev/null`.strip
      out.empty? ? Dir.pwd : out
    end
  end

  def locate
    given = ENV["STORE_FILE"].to_s.strip
    unless given.empty?
      path = File.expand_path(given, root)
      raise Error, "STORE_FILE #{given} does not exist." unless File.file?(path)
      return path
    end
    found = [File.join(root, "store.yml")] + Dir.glob(File.join(root, "*", "store.yml"))
    found = found.select { |p| File.file?(p) }.reject { |p| p.include?("/.github/") }
    raise Error, "No store.yml at the repository root or one directory below it. ./release.sh setup writes one." if found.empty?
    raise Error, "More than one store.yml (#{found.map { |p| rel(p) }.join(', ')}); set STORE_FILE to the one to use." if found.size > 1
    found.first
  end

  def rel(path)
    path = File.expand_path(path)
    return "." if path == root
    path.start_with?(root + "/") ? path[(root.size + 1)..-1] : path
  end

  def str(value)
    value.nil? ? "" : value.to_s.strip
  end

  # Everything a release needs, flat, with every default filled in.
  def load(path = locate)
    # The one-argument form: Psych 3 (Ruby 2.6) and Psych 4 disagree on the rest.
    data = YAML.safe_load(File.read(path, encoding: "UTF-8")) || {}
    raise Error, "#{rel(path)} is not a mapping." unless data.is_a?(Hash)
    app = data["app"] || {}
    store_dir = File.dirname(File.expand_path(path))
    app_dir = File.expand_path(str(app["dir"]).empty? ? "." : str(app["dir"]), store_dir)
    cfg = {
      "store" => rel(path),
      "app_dir" => rel(app_dir),
      "changelog" => rel(File.expand_path(str(app["changelog"]).empty? ? "CHANGELOG.md" : str(app["changelog"]), store_dir)),
      "flutter" => str(app["flutter"]),
      "env" => str(app["env"]).empty? ? ".env" : str(app["env"]),
      "dart_defines" => Array(data["dart_defines"]).map { |d| str(d) }.reject(&:empty?).join(" "),
      "ios" => data.key?("ios") && data["ios"] ? "true" : "false",
      "android" => data.key?("android") && data["android"] ? "true" : "false"
    }
    errors = []
    errors << "#{rel(path)} has neither an ios nor an android section." if cfg["ios"] == "false" && cfg["android"] == "false"

    if cfg["ios"] == "true"
      ios = data["ios"]
      stack = str(ios["stack"])
      flutter = stack == "flutter"
      cfg.update(
        "ios_stack" => stack,
        "ios_bundle_id" => str(ios["bundle_id"]),
        "ios_team_id" => str(ios["team_id"]),
        "ios_xcode" => str(ios["xcode"]),
        "ios_runner" => str(ios["runner"]).empty? ? "macos-26" : str(ios["runner"]),
        "ios_build_number" => str(ios["build_number"]).empty? ? "clock" : str(ios["build_number"]),
        "ios_build_command" => str(ios["build_command"]),
        "ios_pre_build_command" => str(ios["pre_build_command"]),
        "ios_extra_build_args" => str(ios["extra_build_args"]),
        "ios_archive_path" => str(ios["archive_path"]).empty? && flutter ? "build/ios/archive/Runner.xcarchive" : str(ios["archive_path"]),
        "ios_app_name" => str(ios["app_name"]).empty? && flutter ? "Runner.app" : str(ios["app_name"]),
        "ios_entitlements" => ios.key?("entitlements") ? str(ios["entitlements"]) : (flutter ? "ios/Runner/Runner.entitlements" : ""),
        "ios_extension_entitlements" => (ios["extension_entitlements"] || {}).map { |k, v| "#{str(k)}=#{str(v)}" }.join("\n")
      )
      errors << "ios.stack is #{STACKS['ios'].join(' or ')}, not '#{stack}'." unless STACKS["ios"].include?(stack)
      errors << "ios.bundle_id is missing." if cfg["ios_bundle_id"].empty?
      errors << "ios.team_id is missing (the 10-character Apple team id)." if cfg["ios_team_id"].empty?
      errors << "ios.build_number is clock or commits, not '#{cfg['ios_build_number']}'." unless %w[clock commits].include?(cfg["ios_build_number"])
      if stack == "ios-xcode"
        errors << "ios.build_command is required for ios-xcode: it must leave an xcarchive at ios.archive_path." if cfg["ios_build_command"].empty?
        errors << "ios.archive_path is required for ios-xcode." if cfg["ios_archive_path"].empty?
        errors << "ios.app_name is required for ios-xcode (the .app inside the archive)." if cfg["ios_app_name"].empty?
      end
    end

    if cfg["android"] == "true"
      android = data["android"]
      stack = str(android["stack"])
      flutter = stack == "flutter"
      cfg.update(
        "android_stack" => stack,
        "android_package" => str(android["package"]),
        "android_java" => str(android["java"]).empty? ? "21" : str(android["java"]),
        "android_runner" => str(android["runner"]).empty? ? "ubuntu-24.04" : str(android["runner"]),
        "android_key_alias" => str(android["key_alias"]).empty? ? "upload" : str(android["key_alias"]),
        "android_build_number" => str(android["build_number"]).empty? ? "clock" : str(android["build_number"]),
        "android_build_command" => str(android["build_command"]),
        "android_pre_build_command" => str(android["pre_build_command"]),
        "android_extra_build_args" => str(android["extra_build_args"]),
        "android_artifact_path" => str(android["artifact_path"]).empty? ? (flutter ? "build/app/outputs/bundle/release/app-release.aab" : "app/build/outputs/bundle/release/app-release.aab") : str(android["artifact_path"]),
        "android_keystore_path" => str(android["keystore_path"]),
        "android_key_properties" => android.key?("key_properties") ? str(android["key_properties"]) : (flutter ? "android/key.properties" : "")
      )
      errors << "android.stack is #{STACKS['android'].join(' or ')}, not '#{stack}'." unless STACKS["android"].include?(stack)
      errors << "android.package is missing." if cfg["android_package"].empty?
      errors << "android.build_number is clock or commits, not '#{cfg['android_build_number']}'." unless %w[clock commits].include?(cfg["android_build_number"])
      errors << "android.build_command is required for android-gradle: every project names its version properties differently." if stack == "android-gradle" && cfg["android_build_command"].empty?
    end

    listing = data["listing"] || {}
    shots = listing["screenshots"] || {}
    cfg.update(
      "listing_dir" => str(listing["dir"]).empty? ? "listing" : str(listing["dir"]),
      "listing_copyright" => str(listing["copyright"]),
      "listing_support_url" => str(listing["support_url"]),
      "listing_privacy_url" => str(listing["privacy_url"]),
      "listing_marketing_url" => str(listing["marketing_url"]),
      "listing_screenshots_ios" => str(shots["ios"]),
      "listing_screenshots_android" => str(shots["android"]),
      "listing_languages" => (listing["languages"] || {}).map do |section, loc|
        loc = {} unless loc.is_a?(Hash)
        errors << "listing.languages.#{section} needs app_store and play." if str(loc["app_store"]).empty? || str(loc["play"]).empty?
        [str(section), str(loc["app_store"]), str(loc["play"])].join("\t")
      end.join("\n")
    )

    uses_flutter = cfg["ios_stack"] == "flutter" || cfg["android_stack"] == "flutter"
    errors << "app.flutter is missing: the exact Flutter version the app builds with (flutter --version)." if uses_flutter && cfg["flutter"].empty?
    raise Error, "#{rel(path)}:\n  " + errors.join("\n  ") unless errors.empty?
    cfg
  end

  def run(argv)
    case argv.first
    when "locate" then puts rel(locate)
    when "check" then load
    when "shell"
      load.each { |k, v| puts "export SR_#{k.upcase}=#{Shellwords.escape(v)}" }
    when "github"
      out = ENV["GITHUB_OUTPUT"] or raise Error, "GITHUB_OUTPUT is not set."
      File.open(out, "a") do |f|
        load.each do |k, v|
          if v.include?("\n")
            eof = "EOF_#{rand(36**12).to_s(36)}"
            f.puts "#{k}<<#{eof}", v, eof
          else
            f.puts "#{k}=#{v}"
          end
        end
      end
    else
      warn "usage: config.rb locate|check|shell|github"
      exit 2
    end
  rescue Error, Psych::SyntaxError => e
    msg = "store.yml: #{e.message}"
    puts(ENV["GITHUB_ACTIONS"] == "true" ? "::error::#{msg.gsub("\n", '%0A')}" : msg)
    exit 1
  end
end

StoreConfig.run(ARGV) if $PROGRAM_NAME == __FILE__
