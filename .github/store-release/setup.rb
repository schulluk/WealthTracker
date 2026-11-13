#!/usr/bin/env ruby
# frozen_string_literal: true

# Onboarding: finds what this app still lacks for a release and asks for it,
# one value at a time, each with a default wherever one can be found: the
# app's own project files, the other apps on this Mac, App Store Connect and
# Google Play. Enter takes the default, "-" leaves a value empty.
#
#   ./release.sh setup [--plan] [--only PARTS]
#
#   --plan        ask nothing, write nothing: list what it would ask, with the
#                 defaults it found. Exits 10 when something is missing, so
#                 release.sh and the store-release skill can tell.
#   --only PARTS  some of repo,store,env,listing,secrets (comma-separated)
#
# The parts, in this order:
#   repo      .gitignore covers every credential file; CHANGELOG.md exists
#             and has ## Next
#   store     store.yml: platforms, ids, toolchain pins, build settings, the
#             listing's copyright and URLs, the App Review contact, and a
#             What's New line for every other language
#   env       .env and key.properties, for ./release.sh --local on this Mac
#   listing   listing/<language>.md, imported from the stores when the app is
#             in them, else an empty en.md to fill in
#   secrets   what the GitHub repo's production environment lacks; secrets.sh
#             writes it, after its own confirmation
#
# Run it again any time: it asks only for what is still missing. Passwords
# and keys are typed hidden or read from their files: none is printed, none
# goes into store.yml. The other apps are found under ~/git (SR_APPS_ROOT).
# Ruby 2.6 compatible, like config.rb.

require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"
require "yaml"
begin
  require "io/console"
rescue LoadError
  nil
end
require_relative "config"

# Project files are UTF-8 whatever the terminal's locale says.
Encoding.default_external = Encoding::UTF_8

module Setup
  module_function

  PARTS = %w[repo store env listing secrets].freeze
  DIR = __dir__
  KEY_DIRS = %w[~/.private_keys ~/.appstoreconnect/private_keys ~/Downloads/_keys ~/Downloads].freeze
  # Each pattern with a path it must cover.
  IGNORES = {
    ".env" => ".env", "*.p8" => "AuthKey_X.p8", "*.p12" => "x.p12", "*.jks" => "x.jks",
    "*.keystore" => "x.keystore", "key.properties" => "android/key.properties",
    "*service-account*.json" => "play-service-account.json", "secrets.local.env" => "secrets.local.env"
  }.freeze
  # What's New for a language the changelog is not written in, when no other
  # app has a line for it yet.
  NOTES = {
    "de" => "Fehlerbehebungen und Verbesserungen.", "fr" => "Corrections et améliorations.",
    "it" => "Correzioni e miglioramenti.", "es" => "Correcciones y mejoras.",
    "pt" => "Correções e melhorias.", "nl" => "Bugfixes en verbeteringen.",
    "sv" => "Buggfixar och förbättringar.", "da" => "Fejlrettelser og forbedringer.",
    "no" => "Feilrettinger og forbedringer.", "fi" => "Virhekorjauksia ja parannuksia.",
    "pl" => "Poprawki błędów i ulepszenia.", "cs" => "Opravy chyb a vylepšení.",
    "tr" => "Hata düzeltmeleri ve iyileştirmeler.", "ru" => "Исправления ошибок и улучшения.",
    "ja" => "不具合の修正と改善。", "ko" => "버그 수정 및 개선.", "zh" => "错误修复和改进。"
  }.freeze
  SECRETS_IOS = %w[APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_B64
                   APPLE_DISTRIBUTION_P12_B64 APPLE_DISTRIBUTION_P12_PASSWORD].freeze
  SECRETS_ANDROID = %w[GOOGLE_PLAY_SERVICE_ACCOUNT_JSON ANDROID_KEYSTORE_B64 ANDROID_KEYSTORE_PASSWORD
                       ANDROID_KEY_PASSWORD].freeze
  # Files a build often needs that a repository often leaves out.
  SECRET_FILE_CANDIDATES = %w[android/app/google-services.json ios/Runner/GoogleService-Info.plist
                              lib/firebase_options.dart ios/Flutter/Secrets.xcconfig].freeze

  class NoAnswer < StandardError; end

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def dig(hash, keys)
    keys.reduce(hash) { |h, k| h.is_a?(Hash) ? h[k] : nil }
  end

  def has_key?(hash, keys)
    parent = dig(hash, keys[0..-2])
    parent.is_a?(Hash) && parent.key?(keys.last)
  end

  def deep_set(hash, keys, value)
    parent = keys[0..-2].reduce(hash) do |h, k|
      h[k] = {} unless h[k].is_a?(Hash)
      h[k]
    end
    parent[keys.last] = value
  end

  # KEY=VALUE lines (a .env, key.properties) as a hash; read, never sourced.
  def properties(path)
    out = {}
    return out unless path && File.file?(path)
    File.foreach(path, encoding: "UTF-8") do |line|
      next unless line =~ /\A\s*(?:export\s+)?([A-Za-z_][\w.]*)\s*[=:]\s*(.*?)\s*\z/
      value = Regexp.last_match(2)
      value = value[1..-2] if value.length >= 2 && value[0] == value[-1] && %w[" '].include?(value[0])
      out[Regexp.last_match(1)] = value
    end
    out
  end

  # The value most sources agree on, and where it came from.
  def most_common(pairs)
    pairs = pairs.reject { |v, _| blank?(v) }
    return [nil, nil] if pairs.empty?
    groups = pairs.group_by { |v, _| v }
    value, members = groups.max_by { |_, m| m.size }
    sources = members.map(&:last).uniq
    [value, sources.size == 1 ? sources.first : "#{sources.first} and #{sources.size - 1} more"]
  end

  def run(*cmd)
    out, status = Open3.capture2e(*cmd)
    status.success? ? out : nil
  rescue SystemCallError
    nil
  end

  def tty?
    $stdin.tty? && $stdout.tty?
  end

  # ─────────────────────────────── asking ───────────────────────────────

  class Asker
    attr_accessor :part
    attr_reader :pending

    def initialize(plan)
      @plan = plan
      @pending = []
    end

    def plan?
      @plan
    end

    # A value. Enter takes the default, "-" leaves it empty.
    def ask(key, question, default = nil, from: nil, optional: false)
      default = default.to_s
      if @plan
        shown = default.empty? ? (optional ? "(none)" : "(no default: asked)") : default
        @pending << [part, key, shown, from]
        return default
      end
      hint = default.empty? ? (optional ? " (Enter: none)" : "") : " [#{default}]"
      hint += " (#{from})" if from && !default.empty?
      loop do
        value = prompt("#{question}#{hint}: ").strip
        return "" if value == "-"
        return value unless value.empty?
        return default unless default.empty?
        return "" if optional
        puts "    (this one needs a value)"
      end
    end

    def yes?(key, question, default = true)
      if @plan
        @pending << [part, key, default ? "yes" : "no", nil]
        return default
      end
      loop do
        value = prompt("#{question}? [#{default ? 'Y/n' : 'y/N'}] ").strip.downcase
        return default if value.empty?
        return true if %w[y yes j ja].include?(value)
        return false if %w[n no nein].include?(value)
      end
    end

    # One of several [text, value] options; nil for "something else".
    def choose(key, question, options, from: nil)
      if @plan
        @pending << [part, key, options.first[0], nil]
        return options.first[1]
      end
      puts "  #{question}:"
      options.each_with_index { |(text, _), i| puts "    #{i + 1}) #{text}" }
      puts "    #{options.size + 1}) someone else"
      loop do
        value = prompt("[1]: ").strip
        i = value.empty? ? 1 : value.to_i
        return options[i - 1][1] if i.between?(1, options.size)
        return nil if i == options.size + 1
      end
    end

    # A credential, typed hidden and never shown. "" when skipped.
    def secret(key, question)
      if @plan
        @pending << [part, key, "(typed, hidden)", nil]
        return ""
      end
      text = "  #{question} (hidden; Enter skips): "
      if $stdin.tty? && $stdin.respond_to?(:getpass)
        value = $stdin.getpass(text)
        raise NoAnswer if value.nil?
        value.chomp
      else
        prompt(text.strip + " ").chomp
      end
    end

    # A file that must exist, as an absolute path; "" when left empty.
    def file(key, question, default = nil, from: nil, optional: false)
      loop do
        value = ask(key, question, default, from: from, optional: optional)
        return value if value.empty? || @plan
        path = File.expand_path(value)
        return path if File.file?(path)
        puts "    (no file at #{path})"
        default = nil
      end
    end

    private

    def prompt(text)
      $stdout.print "  #{text}"
      $stdout.flush
      line = $stdin.gets
      raise NoAnswer if line.nil?
      line
    end
  end

  # ───────────────────────────── store.yml text ─────────────────────────────

  # Edits store.yml as text, so its comments survive. A commented-out
  # template line for a key is reused, so the explanation stays next to it.
  class YamlText
    def initialize(text)
      @lines = text.split("\n")
    end

    def to_s
      @lines.join("\n").gsub(/\n{3,}/, "\n\n").sub(/\n*\z/, "\n")
    end

    # keys is a path of mapping keys; value a scalar, an Array (written
    # inline) or a flat Hash (written as a block, replacing what was there).
    def set(keys, value)
      put(keys, value, -1, @lines.size - 1, 0)
    end

    def remove(keys)
      head, last = -1, @lines.size - 1
      keys.each_with_index do |key, depth|
        idx, commented = find(key, head + 1, last, depth * 2)
        return if idx.nil? || commented
        head, last = idx, children_last(idx, depth * 2)
      end
      # A nested key's own explanation goes with it.
      head -= 1 while keys.size > 1 && head.positive? && comment?(@lines[head - 1]) &&
                      logical_indent(@lines[head - 1]) == (keys.size - 1) * 2
      @lines.slice!(head..last)
    end

    private

    def uncomment(line)
      line.sub(/\A(\s*)# ?/, '\1')
    end

    def comment?(line)
      line.lstrip.start_with?("#")
    end

    def key_line?(line, indent, key)
      line.start_with?(" " * indent + key + ":") && line[indent + key.length + 1].to_s =~ /\A(\s|)\z/ &&
        line[0, indent] =~ /\A *\z/
    end

    # A comment counts as the line it would be without its "# ".
    def logical_indent(line)
      return nil if line.strip.empty?
      text = comment?(line) ? uncomment(line) : line
      text[/\A */].length
    end

    def find(key, lo, hi, indent)
      commented = nil
      (lo..hi).each do |i|
        line = @lines[i]
        return [i, false] if key_line?(line, indent, key)
        commented ||= i if comment?(line) && key_line?(uncomment(line), indent, key)
      end
      [commented, commented ? true : nil]
    end

    def children_last(idx, indent)
      last = idx
      (idx + 1...@lines.size).each do |i|
        li = logical_indent(@lines[i])
        next if li.nil?
        break if li <= indent
        last = i
      end
      last
    end

    # Where a new key goes in a block: after its last line, before any blank
    # lines and comments that introduce what follows.
    def insert_at(head, last, indent)
      at = last
      while at > head && (@lines[at].strip.empty? || (comment?(@lines[at]) && logical_indent(@lines[at]) <= indent && indent.zero?))
        at -= 1
      end
      at + 1
    end

    def scalar(value)
      s = value.to_s
      return "''" if s.empty?
      plain = s !~ /\A[\s\-?:,\[\]{}#&*!|>'"%@`.+\d]/ && s !~ /\s\z/ && s !~ /:\s|\s#|:\z/ &&
              s !~ /\A(true|false|yes|no|on|off|null|y|n|~)\z/i
      plain ? s : "'#{s.gsub("'", "''")}'"
    end

    def render(key, value, indent)
      sp = " " * indent
      case value
      when Hash
        return ["#{sp}#{key}: {}"] if value.empty?
        ["#{sp}#{key}:"] + value.map { |k, v| "#{sp}  #{k}: #{scalar(v)}" }
      when Array then ["#{sp}#{key}: [#{value.map { |v| scalar(v) }.join(', ')}]"]
      else ["#{sp}#{key}: #{scalar(value)}"]
      end
    end

    # The old line's trailing comment, kept at its column.
    def with_comment(new_line, old_line)
      text = comment?(old_line) ? uncomment(old_line) : old_line
      colon = text.index(":")
      rest = colon ? text[(colon + 1)..-1] : ""
      m = rest.match(/\s(#\s.*)\z/)
      return new_line unless m
      column = colon + 1 + m.begin(1)
      new_line + " " * [column - new_line.length, 2].max + m[1]
    end

    def put(keys, value, head, last, indent)
      key = keys.first
      idx, commented = head + 1 <= last ? find(key, head + 1, last, indent) : [nil, nil]
      if keys.size > 1
        if idx.nil?
          idx = insert_at(head, last, indent)
          @lines.insert(idx, "" ) if indent.zero? && idx.positive? && !@lines[idx - 1].strip.empty?
          idx += 1 if indent.zero? && @lines[idx] == ""
          @lines.insert(idx, "#{' ' * indent}#{key}:")
        elsif commented || @lines[idx] =~ /:\s*(\{\}|\[\]|''|""|~|null)\s*(#.*)?\z/
          # A parent that was commented out or empty ({}) gets children now.
          @lines[idx] = with_comment("#{' ' * indent}#{key}:", @lines[idx])
        end
        put(keys[1..-1], value, idx, children_last(idx, indent), indent + 2)
        return
      end
      lines = render(key, value, indent)
      if idx.nil?
        at = insert_at(head, last, indent)
        if indent.zero? && at.positive? && !@lines[at - 1].strip.empty?
          @lines.insert(at, "")
          at += 1
        end
        @lines.insert(at, *lines)
      elsif value.is_a?(Hash)
        @lines[idx..children_last(idx, indent)] = lines
      else
        @lines[idx] = with_comment(lines.first, @lines[idx])
      end
    end
  end

  # ─────────────────────────────── the app ───────────────────────────────

  # What the app's own files say.
  class Project
    attr_reader :root

    def initialize(root)
      @root = root
      @memo = {}
    end

    def memo(name)
      @memo.key?(name) ? @memo[name] : (@memo[name] = yield)
    end

    def flutter_dir
      memo(:flutter_dir) do
        ([root] + Dir.glob(File.join(root, "*")).sort).find do |d|
          spec = File.join(d, "pubspec.yaml")
          File.file?(spec) && File.read(spec) =~ /sdk:\s*flutter/ &&
            (File.directory?(File.join(d, "ios")) || File.directory?(File.join(d, "android")))
        end
      end
    end

    def flutter?
      !flutter_dir.nil?
    end

    # The app project: the Flutter app, else the repository.
    def app_dir
      flutter_dir || root
    end

    def xcodeproj
      memo(:xcodeproj) do
        if flutter?
          p = File.join(flutter_dir, "ios", "Runner.xcodeproj")
          File.directory?(p) ? p : nil
        else
          (Dir.glob(File.join(root, "*.xcodeproj")) + Dir.glob(File.join(root, "*", "*.xcodeproj")))
            .reject { |p| p =~ %r{/(Pods|build|DerivedData)/} }.min
        end
      end
    end

    def gradle_file(dir)
      %w[build.gradle.kts build.gradle].map { |f| File.join(dir, f) }.find { |f| File.file?(f) }
    end

    # The Android app module: where its applicationId is.
    def android_module
      memo(:android_module) do
        if flutter?
          d = File.join(flutter_dir, "android", "app")
          gradle_file(d) ? d : nil
        else
          [root, *Dir.glob(File.join(root, "*"))].select { |d| gradle_file(d) || Dir.glob(File.join(d, "settings.gradle*")).any? }
                                                  .map { |d| File.join(d, "app") }.find { |d| gradle_file(d) }
        end
      end
    end

    def changelog
      [app_dir, root].uniq.map { |d| File.join(d, "CHANGELOG.md") }.find { |f| File.file?(f) }
    end

    # A path relative to the app project, as store.yml writes them.
    def app_rel(path)
      path = File.expand_path(path)
      return "." if path == app_dir
      path.start_with?(app_dir + "/") ? path[(app_dir.size + 1)..-1] : path
    end

    def pbx
      memo(:pbx) do
        f = xcodeproj && File.join(xcodeproj, "project.pbxproj")
        f && File.file?(f) ? File.read(f) : ""
      end
    end

    def bundle_id
      ids = pbx.scan(/PRODUCT_BUNDLE_IDENTIFIER = "?([^";]+)"?;/).flatten.uniq
               .reject { |id| id.include?("$(") || id =~ /tests?\z/i }
      ids.min_by { |id| [-ids.count { |o| o.start_with?(id) }, id.length] }
    end

    def team_id
      teams = pbx.scan(/DEVELOPMENT_TEAM = "?([A-Z0-9]{10})"?;/).flatten
      Setup.most_common(teams.map { |t| [t, "the Xcode project"] }).first
    end

    def marketing_version
      versions = pbx.scan(/MARKETING_VERSION = "?(\d+\.\d+(?:\.\d+)?)"?;/).flatten.uniq
      versions.max_by { |v| Gem::Version.new(v) }
    end

    # CODE_SIGN_ENTITLEMENTS, relative to the app project.
    def entitlements
      return [] unless xcodeproj
      base = File.dirname(xcodeproj)
      pbx.scan(/CODE_SIGN_ENTITLEMENTS = "?([^";]+)"?;/).flatten.uniq.map { |e| app_rel(File.join(base, e)) }
    end

    def main_entitlements
      found = entitlements.select { |e| File.file?(File.join(app_dir, e)) }
      if flutter?
        runner = found.select { |e| e.include?("Runner/") }
        runner.find { |e| e.end_with?("Runner.entitlements") } || runner.find { |e| e.include?("Release") } || runner.first
      else
        name = File.basename(xcodeproj.to_s, ".xcodeproj")
        found.find { |e| File.basename(e, ".entitlements") == name } || found.first
      end
    end

    # [[Name.appex, its entitlements]] for every app extension that has some.
    def extensions
      appexes = pbx.scan(/path = "?([^";\/]+\.appex)"?;/).flatten.uniq
      others = entitlements.select { |e| File.file?(File.join(app_dir, e)) } - [main_entitlements]
      others = others.reject { |e| e.include?("Runner/") } if flutter?
      appexes.map do |appex|
        ent = others.find do |e|
          appex.start_with?(File.basename(File.dirname(e))) || appex.start_with?(File.basename(e, ".entitlements"))
        end
        ent ||= others.first if appexes.size == 1 && others.size == 1
        ent && [appex, ent]
      end.compact
    end

    def flutterfire_phase?
      pbx.include?("flutterfire")
    end

    def application_id
      f = android_module && gradle_file(android_module)
      f && File.read(f)[/applicationId\s*=?\s*["']([^"']+)["']/, 1]
    end

    def version_name
      f = android_module && gradle_file(android_module)
      f && File.read(f)[/versionName\s*=?\s*["'](\d+\.\d+(?:\.\d+)?)["']/, 1]
    end

    def pubspec_version
      spec = flutter? && File.join(flutter_dir, "pubspec.yaml")
      spec && File.read(spec)[/^version:\s*(\d+\.\d+\.\d+)/, 1]
    end

    def key_properties_path
      flutter? ? File.join(flutter_dir, "android", "key.properties") : nil
    end

    # Names the Dart code reads with String/bool/int.fromEnvironment.
    def dart_defines
      return [] unless flutter?
      names = []
      Dir.glob(File.join(flutter_dir, "lib", "**", "*.dart")).each do |f|
        File.read(f).scan(/(?:String|bool|int)\.fromEnvironment\(\s*['"]([A-Za-z][A-Za-z0-9_]*)['"]/) { |m| names << m[0] }
      end
      names.uniq.reject { |n| n.start_with?("FLUTTER_") }.sort
    end

    def flutter_version
      out = Setup.run("flutter", "--version", "--machine").to_s
      (JSON.parse(out[/\{.*\}/m]) rescue {})["frameworkVersion"]
    end

    def xcode_version
      Setup.run("xcodebuild", "-version").to_s[/^Xcode (\S+)/, 1]
    end

    # The JDK major this Mac builds Android with (Flutter's jdk-dir, else
    # JAVA_HOME, else the java on the PATH).
    def java_version
      home = (JSON.parse(Setup.run("flutter", "config", "--machine").to_s[/\{.*\}/m]) rescue {})["jdk-dir"] if flutter?
      home ||= ENV["JAVA_HOME"]
      java = home ? File.join(home, "bin", "java") : "java"
      out = Setup.run(java, "-version").to_s
      v = out[/version "(\d+)(?:\.(\d+))?/, 1]
      v == "1" ? out[/version "1\.(\d+)/, 1] : v
    end

    # A script that leaves an xcarchive, for stack: ios-xcode.
    def archive_script
      found = %w[tools scripts ci bin].flat_map { |d| Dir.glob(File.join(app_dir, d, "*archive*.sh")) }.min
      found && app_rel(found)
    end

    # Where that script says it leaves the archive (a literal path in it).
    def archive_path
      script = archive_script
      script && File.read(File.join(app_dir, script))[%r{(?<![\w$/])[\w.-]+(?:/[\w.-]+)*/[\w.-]+\.xcarchive}]
    end

    def ignored?(rel)
      system("git", "-C", root, "check-ignore", "-q", "--no-index", rel, out: File::NULL, err: File::NULL)
    end

    def tracked?(rel)
      !Setup.run("git", "-C", root, "ls-files", "--error-unmatch", rel).nil?
    end

    def github_slug
      origin = Setup.run("git", "-C", root, "remote", "get-url", "origin").to_s.strip
      slug = origin.sub(%r{\A(git@github\.com:|https://github\.com/)}, "").sub(/\.git\z/, "")
      slug =~ %r{\A[^/\s]+/[^/\s]+\z} && slug != origin ? slug : nil
    end
  end

  # The other apps on this Mac: what their store.yml, .env and key.properties
  # say, as defaults for this one.
  class Neighbors
    def initialize(root)
      git = File.expand_path("~/git")
      @base = ENV["SR_APPS_ROOT"] || (root.start_with?(git + "/") ? git : File.dirname(root))
      @root = root
      @memo = {}
    end

    def glob(name)
      @memo[name] ||= Dir.glob(File.join(@base, "{*,*/*,*/*/*}", name))
                         .reject { |p| p.start_with?(@root + "/") || p =~ %r{/(\.github|\.claude|node_modules|build|Pods)/} }
                         .sort
    end

    def label(path)
      path.sub(@base + "/", "")
    end

    def stores
      @memo[:stores] ||= glob("store.yml").map do |p|
        data = (YAML.safe_load(File.read(p, encoding: "UTF-8")) rescue nil)
        data.is_a?(Hash) ? [p, data] : nil
      end.compact
    end

    # [value, label] for keys in every other store.yml.
    def store_values(keys)
      stores.map { |p, d| [Setup.dig(d, keys), label(p)] }.reject { |v, _| Setup.blank?(v) || v.is_a?(Hash) }
    end

    def envs
      @memo[:envs] ||= glob(".env").map { |p| [p, Setup.properties(p)] }.reject { |_, e| e.empty? }
    end

    # [value, label] for one key of every other .env; paths made absolute.
    def env_values(key, path: false)
      envs.map do |p, e|
        v = e[key]
        next if Setup.blank?(v)
        v = File.expand_path(v, File.dirname(p)) if path
        next if path && !File.file?(v)
        [v, label(p)]
      end.compact
    end

    def key_properties
      @memo[:kp] ||= glob("android/key.properties").map { |p| [p, Setup.properties(p)] }
    end
  end

  # ─────────────────────────────── the run ───────────────────────────────

  class Run
    def initialize(argv)
      @plan = false
      @only = PARTS.dup
      until argv.empty?
        case (arg = argv.shift)
        when "--plan" then @plan = true
        when "--only" then @only = argv.shift.to_s.split(",").map(&:strip)
        when "-h", "--help"
          puts File.read(__FILE__)[/^# Onboarding.*?(?=^\s*$)/m].gsub(/^# ?/, "")
          exit 0
        else abort "setup: unknown argument #{arg} (see --help)"
        end
      end
      unknown = @only - PARTS
      abort "setup: --only takes #{PARTS.join(', ')}, not #{unknown.join(', ')}" unless unknown.empty?
      abort "setup: run it inside the app's git repository." if Setup.run("git", "rev-parse", "--show-toplevel").nil?
      @root = StoreConfig.root
      Dir.chdir(@root)
      @ask = Asker.new(@plan)
      @project = Project.new(@root)
      @others = Neighbors.new(@root)
      @report = []
      @tmp = Dir.mktmpdir("store-setup")
      at_exit { FileUtils.rm_rf(@tmp) }
    end

    def call
      unless @plan
        puts "Setting up releases for #{File.basename(@root)}. Enter takes the [default], - leaves a value empty,"
        puts "Ctrl-C stops without writing the part you are in."
      end
      @only.each do |part|
        @ask.part = part
        puts "\n#{part}" unless @plan
        send("part_#{part}")
      end
      finish
    rescue NoAnswer
      warn "\nsetup asks questions and got no answer. Run ./release.sh setup in a terminal, " \
           "or ./release.sh setup --plan for the list of what it would ask."
      exit 2
    rescue Interrupt
      warn "\nStopped."
      exit 130
    end

    private

    def rel(path)
      StoreConfig.rel(path)
    end

    def report(text)
      @report << [@ask.part, text]
      puts "  #{text}" unless @plan
    end

    # What happened, or under --plan what would.
    def did(done, would)
      @plan ? would : done
    end

    def store_path
      @store_path ||= (StoreConfig.locate rescue nil)
    end

    def store_data
      @store_data ||= store_path ? (YAML.safe_load(File.read(store_path, encoding: "UTF-8")) || {}) : {}
    end

    # The flat config release.sh sees, or nil while store.yml is incomplete.
    def config
      return nil unless store_path
      StoreConfig.load(store_path)
    rescue StoreConfig::Error
      nil
    end

    def app_dir_abs
      cfg = config
      cfg ? File.expand_path(cfg["app_dir"], @root) : @project.app_dir
    end

    def env_path
      cfg = config
      cfg ? File.join(app_dir_abs, cfg["env"]) : File.join(@project.app_dir, ".env")
    end

    def env
      Setup.properties(env_path)
    end

    def locales
      @locales ||= JSON.parse(Setup.run("python3", File.join(DIR, "listing.py"), "--locales").to_s) rescue {}
    end

    # ─────────────────────────── the stores, read only ───────────────────────────

    # An .env with a usable App Store Connect key: this app's, else another app's
    # (the key belongs to the team, not the app).
    def asc_env
      candidates = [env_path] + @others.envs.map(&:first)
      candidates.find do |p|
        e = Setup.properties(p)
        !Setup.blank?(e["ASC_KEY_ID"]) && !Setup.blank?(e["ASC_ISSUER_ID"]) && !Setup.blank?(e["ASC_KEY_PATH"]) &&
          File.file?(File.expand_path(e["ASC_KEY_PATH"], File.dirname(p)))
      end
    end

    def play_key
      e = env
      own = e["GOOGLE_PLAY_JSON_KEY_PATH"] || e["PLAY_STORE_JSON_KEY"]
      own = own && File.expand_path(own, File.dirname(env_path))
      return own if own && File.file?(own)
      fastlane = File.join(@project.app_dir, "android", "fastlane", "play-store-key.json")
      return fastlane if File.file?(fastlane)
      # The service account belongs to the developer account, so another
      # app's key reads this app too.
      Setup.most_common(@others.env_values("GOOGLE_PLAY_JSON_KEY_PATH", path: true) +
                        @others.glob("android/fastlane/play-store-key.json").map { |p| [p, @others.label(p)] }).first
    end

    # What the stores say about this app (store-lookup.sh), once per run.
    def lookup
      return @lookup if defined?(@lookup)
      @lookup = nil
      data = store_data
      bundle = Setup.dig(data, %w[ios bundle_id]) || (@project.xcodeproj && @project.bundle_id)
      package = Setup.dig(data, %w[android package]) || @project.application_id
      args = []
      asc = asc_env
      args += ["--from-env", asc, "--bundle-id", bundle] if asc && !Setup.blank?(bundle)
      key = play_key
      args += ["--package", package, "--play-key", key] if key && !Setup.blank?(package)
      return nil if args.empty? || Setup.run("which", "fastlane").nil?
      args += ["--project", @project.flutter_dir] if @project.flutter?
      @listing_json = File.join(@tmp, "listing.json")
      $stdout.puts "  (asking App Store Connect and Google Play for defaults; read only, about half a minute)"
      out, err, status = Open3.capture3({ "SD_LISTING_JSON" => @listing_json }, File.join(DIR, "store-lookup.sh"), *args)
      unless status.success?
        puts "  (the store lookup failed, so no defaults from the stores: #{err.lines.last.to_s.strip})"
        return nil
      end
      @lookup = YAML.safe_load(out) || {}
    rescue SystemCallError, Psych::Exception
      @lookup = nil
    end

    # ───────────────────────────────── repo ─────────────────────────────────

    def part_repo
      base = rel(@project.app_dir)
      sample = ->(s) { base == "." ? s : File.join(base, s) }
      missing = IGNORES.reject { |_, s| @project.ignored?(sample.call(s)) }.keys
      if missing.empty?
        report ".gitignore covers the credential files"
      elsif @ask.yes?(".gitignore", "Add #{missing.join(' ')} to .gitignore, so no credential gets committed", true)
        unless @ask.plan?
          path = File.join(@root, ".gitignore")
          text = File.file?(path) ? File.read(path) : ""
          text += "\n" unless text.empty? || text.end_with?("\n")
          File.write(path, text + "\n# Release credentials (store-release)\n" + missing.join("\n") + "\n")
        end
        report ".gitignore: #{did('added', 'would add')} #{missing.join(' ')}"
      end
      tracked = Setup.run("git", "ls-files", "--", "*.p8", "*.p12", "*.jks", "*.keystore", "*key.properties",
                          ".env", "*/.env", "*secrets.local.env", "*service-account*.json").to_s.split("\n")
      tracked.each { |t| report "WARNING: #{t} is committed. Take it out (git rm --cached) and treat what it holds as leaked." }
      repo_changelog
    end

    def repo_changelog
      path = @project.changelog
      if path
        _, err, = Open3.capture3("ruby", File.join(DIR, "changelog.rb"), "check", "--changelog", path)
        errors = err.lines.map(&:strip).select { |l| l.start_with?("error:") }
        if errors.empty?
          report "#{rel(path)} has ## Next"
        elsif errors.any? { |e| e.include?("no '## Next' section") } &&
              @ask.yes?("CHANGELOG.md", "#{rel(path)} has no ## Next. Add an empty one at the top (the release counts its version from the ## X.Y.Z below it)", true)
          unless @ask.plan?
            text = File.read(path)
            at = text.index(/^## /) || text.length
            File.write(path, text[0...at] + "## Next\n\n### Public\n\n### Internal\n\n" + text[at..-1].to_s)
          end
          report "#{rel(path)}: #{did('added', 'would add')} ## Next"
        else
          errors.each { |e| report "#{rel(path)}: #{e.sub('error: ', '')} (fix by hand; references/changelog.md)" }
        end
        return
      end
      dir = @project.app_dir
      return unless @ask.yes?("CHANGELOG.md", "Create #{rel(File.join(dir, 'CHANGELOG.md'))}, with an empty ## Next (the release counts its version from it)", true)
      version, from = current_version
      version = @ask.ask("CHANGELOG.md base", "The version in the stores now; ## Next counts on from it", version || "0.0.0", from: from)
      unless @ask.plan?
        File.write(File.join(dir, "CHANGELOG.md"),
                   "# Changelog\n\n## Next\n\n### Public\n\n### Internal\n\n## #{version}\n")
      end
      report "#{rel(File.join(dir, 'CHANGELOG.md'))}: #{did('created', 'would create it')}, counting from #{version}"
    end

    def current_version
      [[@project.pubspec_version, "pubspec.yaml"], [@project.marketing_version, "MARKETING_VERSION"],
       [@project.version_name, "versionName"]].find { |v, _| v } || [nil, nil]
    end

    # ───────────────────────────────── store ─────────────────────────────────

    def part_store
      creating = store_path.nil?
      path = store_path || File.join(File.dirname(@project.changelog || File.join(@project.app_dir, "x")), "store.yml")
      if creating
        template = [File.join(DIR, "store.template.yml"), File.join(DIR, "..", "templates", "store.yml")].find { |f| File.file?(f) }
        abort "setup: no store.yml template next to #{__FILE__}" unless template
        text = File.read(template, encoding: "UTF-8")
        @store_data = {}
        report "#{rel(path)} does not exist yet: it is written from the template"
      else
        text = File.read(path, encoding: "UTF-8")
      end
      data = store_data
      y = YamlText.new(text)
      changed = []
      set = lambda do |keys, value|
        y.set(keys, value)
        Setup.deep_set(data, keys, value)
        changed << keys.join(".")
      end
      missing = ->(*keys) { creating || Setup.blank?(Setup.dig(data, keys)) }

      # Platforms
      if creating
        want_ios = !@project.xcodeproj.nil? &&
                   @ask.yes?("ios", "Release #{rel(@project.xcodeproj)} on the App Store", true)
        want_android = !@project.android_module.nil? &&
                       @ask.yes?("android", "Release #{rel(@project.android_module)} on Google Play", true)
        abort "setup: neither an iOS nor an Android project to release here." unless want_ios || want_android
        y.remove(["ios"]) unless want_ios
        y.remove(["android"]) unless want_android
        app_rel = Pathname.new(@project.app_dir).relative_path_from(Pathname.new(File.dirname(path))).to_s
        set.call(%w[app dir], app_rel) unless app_rel == "."
      else
        want_ios = data["ios"].is_a?(Hash)
        want_android = data["android"].is_a?(Hash)
      end
      @want_ios = want_ios
      @want_android = want_android

      store_ios(data, set, missing, creating) if want_ios
      store_android(data, set, missing, creating) if want_android

      stacks = [want_ios && Setup.dig(data, %w[ios stack]), want_android && Setup.dig(data, %w[android stack])]
      if stacks.include?("flutter")
        if missing.call("app", "flutter")
          set.call(%w[app flutter], @ask.ask("app.flutter", "Flutter version to build with", @project.flutter_version,
                                             from: "flutter --version"))
        end
      elsif creating
        y.remove(%w[app flutter])
      end

      store_dart_defines(data, set, creating)
      store_listing(data, set, creating)
      store_review(data, set, creating) if want_ios
      store_notes(data, set, creating)

      if changed.empty? && !creating
        report "#{rel(path)} has everything"
        return
      end
      out = y.to_s
      begin
        YAML.safe_load(out)
      rescue Psych::Exception => e
        abort "setup: the store.yml it would write does not parse (#{e.message}); nothing written. Please report this."
      end
      unless @ask.plan?
        File.write(path, out)
        @store_path = path
        @store_data = nil
        begin
          StoreConfig.load(path)
        rescue StoreConfig::Error => e
          report "still missing: #{e.message.sub(/\A[^\n]*\n/, '').gsub(/\s+/, ' ')}"
        end
      end
      report "#{rel(path)}: #{creating ? did('written', 'would write it') : did('filled in', 'would fill in')} (#{changed.uniq.join(', ')})"
    end

    def store_ios(data, set, missing, creating)
      proj = @project.xcodeproj ? rel(@project.xcodeproj) : nil
      stack = Setup.dig(data, %w[ios stack])
      unless StoreConfig::STACKS["ios"].include?(stack.to_s) && !missing.call("ios", "stack")
        default = @project.flutter? ? "flutter" : "ios-xcode"
        stack = @ask.ask("ios.stack", "How the iOS app is built: flutter or ios-xcode", default,
                         from: @project.flutter? ? "pubspec.yaml" : proj)
        set.call(%w[ios stack], stack)
      end
      if missing.call("ios", "bundle_id")
        set.call(%w[ios bundle_id], @ask.ask("ios.bundle_id", "Bundle id", @project.bundle_id, from: proj))
      end
      if missing.call("ios", "team_id")
        team, from = [@project.team_id, proj]
        team, from = keychain_team if team.nil?
        team, from = Setup.most_common(@others.store_values(%w[ios team_id])) if team.nil?
        set.call(%w[ios team_id], @ask.ask("ios.team_id", "Apple team id (10 characters)", team, from: from))
      end
      if missing.call("ios", "xcode")
        set.call(%w[ios xcode], @ask.ask("ios.xcode", "Xcode version to build with", @project.xcode_version,
                                         from: "xcodebuild -version"))
      end
      xcode = Setup.dig(data, %w[ios xcode]).to_s
      major = xcode.to_i
      # Without one the default, macos-26, which has no Xcode past 26.
      if creating || (Setup.blank?(Setup.dig(data, %w[ios runner])) && major > 26)
        runner, from = Setup.most_common(@others.stores.select { |_, d| Setup.dig(d, %w[ios xcode]).to_s.to_i == major }
                                                   .map { |p, d| [Setup.dig(d, %w[ios runner]), @others.label(p)] })
        runner ||= major > 26 ? "xcode-#{major}" : "macos-26"
        set.call(%w[ios runner], @ask.ask("ios.runner", "GitHub runner image with Xcode #{xcode}", runner, from: from))
      end
      if stack == "flutter"
        ios = data["ios"]
        unless ios.key?("entitlements")
          main = @project.main_entitlements
          if main.nil?
            set.call(%w[ios entitlements], "")
            report "ios.entitlements: none, so the export has no entitlements to check"
          elsif main != "ios/Runner/Runner.entitlements"
            set.call(%w[ios entitlements], main)
          end
        end
        # Asked once: an answer, even "none", is written, so the next run
        # leaves it alone.
        extensions = @project.extensions
        if !ios.key?("extension_entitlements") && !extensions.empty?
          pairs = extensions.select do |appex, ent|
            @ask.yes?("ios.extension_entitlements", "Check that the export keeps #{appex}'s entitlements (#{ent})", true)
          end
          set.call(%w[ios extension_entitlements], pairs.to_h)
        end
        if !ios.key?("pre_build_command") && @project.flutterfire_phase?
          cmd = @ask.ask("ios.pre_build_command", "An Xcode build phase calls flutterfire (Crashlytics symbols), which a runner lacks; command that installs it",
                         "dart pub global activate flutterfire_cli", from: "the Xcode project", optional: true)
          set.call(%w[ios pre_build_command], cmd)
        end
      else
        name = File.basename(@project.xcodeproj.to_s, ".xcodeproj")
        if missing.call("ios", "build_command")
          set.call(%w[ios build_command], @ask.ask("ios.build_command", "Command that leaves an xcarchive (it gets VERSION, BUILD_NUMBER, TRACK, SIGN_IDENTITY)",
                                                   @project.archive_script, from: @project.archive_script && "found in the repo"))
        end
        if missing.call("ios", "archive_path")
          found = @project.archive_path
          set.call(%w[ios archive_path], @ask.ask("ios.archive_path", "Where that command leaves the xcarchive",
                                                  found || "build/#{name}.xcarchive", from: found && @project.archive_script))
        end
        if missing.call("ios", "app_name")
          set.call(%w[ios app_name], @ask.ask("ios.app_name", "The .app inside the archive", "#{name}.app", from: proj))
        end
        unless data["ios"].key?("entitlements")
          ent = @ask.ask("ios.entitlements", "The app's entitlements file, checked after the export", @project.main_entitlements,
                         from: proj, optional: true)
          set.call(%w[ios entitlements], ent)
        end
      end
    end

    def keychain_team
      out = Setup.run("security", "find-identity", "-v", "-p", "codesigning").to_s
      teams = out.scan(/"Apple Distribution: [^"]*\(([A-Z0-9]{10})\)"/).flatten.uniq
      teams.size == 1 ? [teams.first, "the login keychain"] : [nil, nil]
    end

    def store_android(data, set, missing, creating)
      gradle = @project.android_module && @project.gradle_file(@project.android_module)
      stack = Setup.dig(data, %w[android stack])
      unless StoreConfig::STACKS["android"].include?(stack.to_s) && !missing.call("android", "stack")
        default = @project.flutter? ? "flutter" : "android-gradle"
        stack = @ask.ask("android.stack", "How the Android app is built: flutter or android-gradle", default,
                         from: @project.flutter? ? "pubspec.yaml" : gradle && rel(gradle))
        set.call(%w[android stack], stack)
      end
      if missing.call("android", "package")
        set.call(%w[android package], @ask.ask("android.package", "Package name (applicationId)", @project.application_id,
                                               from: gradle && rel(gradle)))
      end
      if creating || !Setup.has_key?(data, %w[android java])
        java, from = [@project.java_version, "the JDK this Mac builds with"]
        java, from = Setup.most_common(@others.store_values(%w[android java])) if java.nil?
        set.call(%w[android java], @ask.ask("android.java", "Java version to build with", java || "21", from: from))
      end
      alias_name = Setup.properties(@project.key_properties_path)["keyAlias"]
      if !Setup.has_key?(data, %w[android key_alias]) && !Setup.blank?(alias_name) && alias_name != "upload"
        set.call(%w[android key_alias], alias_name)
      end
      return unless stack == "android-gradle"
      if missing.call("android", "build_command")
        set.call(%w[android build_command],
                 @ask.ask("android.build_command", "Command that builds the release AAB (it gets VERSION and BUILD_NUMBER, and the KEYSTORE_* and KEY_* signing values)",
                          "./gradlew bundleRelease -PversionName=$VERSION -PversionCode=$BUILD_NUMBER"))
      end
    end

    def store_dart_defines(data, set, creating)
      found = @project.dart_defines
      current = Array(data["dart_defines"]).map(&:to_s)
      if creating || !data.key?("dart_defines")
        return if found.empty?
        names = @ask.ask("dart_defines", "Build-time values the code reads (fromEnvironment), passed as --dart-define",
                         found.join(" "), from: "lib/", optional: true).split(/[\s,]+/).reject(&:empty?)
        set.call(%w[dart_defines], names)
      else
        added = (found - current).select do |name|
          @ask.yes?("dart_defines", "The code also reads #{name}: pass it as --dart-define too", true)
        end
        set.call(%w[dart_defines], current + added) unless added.empty?
      end
    end

    def store_listing(data, set, creating)
      if creating || Setup.blank?(Setup.dig(data, %w[listing copyright]))
        holder, from = Setup.most_common(@others.store_values(%w[listing copyright]))
        holder, from = [Setup.run("git", "config", "user.name").to_s.strip, "git config user.name"] if holder.nil?
        set.call(%w[listing copyright], @ask.ask("listing.copyright", "Copyright holder in the App Store (the year is added at upload)",
                                                 holder, from: from))
      end
      if @want_ios
        { "support_url" => "Support URL", "privacy_url" => "Privacy policy URL", "marketing_url" => "Marketing URL" }.each do |key, label|
          next unless creating || !Setup.has_key?(data, ["listing", key])
          url = (lookup || {}).dig("urls", key)
          set.call(["listing", key], @ask.ask("listing.#{key}", "#{label} (every App Store language)", url,
                                              from: url && "App Store Connect", optional: true))
        end
      end
      { "ios" => "listing/screenshots/ios", "android" => "listing/screenshots/android" }.each do |platform, dir|
        next if Setup.has_key?(data, ["listing", "screenshots", platform])
        next unless platform == "ios" ? @want_ios : @want_android
        set.call(["listing", "screenshots", platform], dir) if File.directory?(File.join(@project.app_dir, dir))
      end
    end

    def store_review(data, set, creating)
      review = data["app_review"].is_a?(Hash) ? data["app_review"] : {}
      return unless creating || %w[first_name last_name email phone].all? { |k| Setup.blank?(review[k]) }
      return if %w[EMAIL PHONE].all? { |k| !Setup.blank?(env["ASC_REVIEW_#{k}"]) } && !creating
      found = lookup || {}
      candidates = []
      candidates << found["app_review"] if found["app_review"]
      candidates += Array(found["app_review_options"])
      @others.stores.each do |p, d|
        r = d["app_review"]
        next unless r.is_a?(Hash) && !Setup.blank?(r["email"])
        candidates << r.merge("from" => @others.label(p))
      end
      candidates = candidates.uniq { |c| [c["email"].to_s.downcase, c["phone"].to_s.delete(" ")] }
      contact = nil
      unless candidates.empty?
        contact = @ask.choose("app_review", "App Review contact (Apple wants it on every version; it differs per app)",
                              candidates.map { |c| ["#{c['first_name']} #{c['last_name']}, #{c['email']}, #{c['phone']}  (#{c['from']})", c] },
                              from: candidates.first["from"])
      end
      if contact.nil?
        first, last = Setup.run("git", "config", "user.name").to_s.strip.split(" ", 2)
        contact = {
          "first_name" => @ask.ask("app_review.first_name", "Review contact: first name", first),
          "last_name" => @ask.ask("app_review.last_name", "Review contact: last name", last),
          "email" => @ask.ask("app_review.email", "Review contact: email", Setup.run("git", "config", "user.email").to_s.strip),
          "phone" => @ask.ask("app_review.phone", "Review contact: phone, with country code (+41...)")
        }
      end
      set.call(%w[app_review first_name], contact["first_name"].to_s)
      set.call(%w[app_review last_name], contact["last_name"].to_s)
      slug = @project.github_slug
      public_repo = slug && Setup.run("gh", "api", "repos/#{slug}", "--jq", ".private").to_s.strip == "false"
      if public_repo && !@ask.yes?("app_review.public", "#{slug} is public: write the contact's email and phone into store.yml anyway", false)
        # Into .env and the GitHub secrets instead (the env and secrets parts).
        @review_private = contact
        set.call(%w[app_review email], "")
        set.call(%w[app_review phone], "")
        report "app_review: email and phone go to .env and the GitHub secrets, not into the public store.yml"
      else
        set.call(%w[app_review email], contact["email"].to_s)
        set.call(%w[app_review phone], contact["phone"].to_s)
      end
    end

    # Every language the listing has besides the one the changelog is written
    # in, as [code, App Store locale, Play locale].
    def other_languages(main)
      table = locales
      dir = File.join(@project.app_dir, Setup.dig(store_data, %w[listing dir]) || "listing")
      files = Dir.glob(File.join(dir, "*.md")).map { |f| File.basename(f, ".md") }.reject { |c| c.upcase.start_with?("README") }
      langs = files.map { |c| [c, *(table[c] || [c, c])] }
      if langs.empty? && (found = lookup)
        by_apple = table.map { |c, (a, _)| [a, c] }.to_h
        by_play = table.map { |c, (_, p)| [p, c] }.to_h
        codes = Array(found.dig("app_store", "locales")).map { |l| by_apple[l] || l } +
                Array(found.dig("play", "locales")).map { |l| by_play[l] || l }
        langs = codes.uniq.map { |c| [c, *(table[c] || [c, c])] }
      end
      langs.reject { |_, a, p| a == main && p == main }
    end

    def store_notes(data, set, creating)
      if creating || Setup.blank?(Setup.dig(data, %w[release_notes locale]))
        set.call(%w[release_notes locale], @ask.ask("release_notes.locale", "The language ### Public is written in, as the stores spell it", "en-US"))
      end
      if creating || !Setup.has_key?(data, %w[release_notes default])
        set.call(%w[release_notes default], @ask.ask("release_notes.default", "What the stores get when ### Public is empty",
                                                     "Bug fixes and improvements."))
      end
      main = Setup.dig(data, %w[release_notes locale]).to_s
      other_languages(main).each do |code, apple, play|
        need_apple = @want_ios && apple != main && Setup.blank?(Setup.dig(data, ["release_notes", "app_store", apple]))
        need_play = @want_android && play != main && Setup.blank?(Setup.dig(data, ["release_notes", "play", play]))
        next unless need_apple || need_play
        default, from = Setup.most_common(@others.store_values(["release_notes", "app_store", apple]) +
                                          @others.store_values(["release_notes", "play", play]))
        default ||= NOTES[code.split("-").first]
        default ||= Setup.dig(data, %w[release_notes default])
        where = [need_apple && "App Store #{apple}", need_play && "Play #{play}"].select { |x| x }.join(", ")
        line = @ask.ask("release_notes.#{code}", "What's New in #{code} (#{where}): the release writes ### Public only in #{main}",
                        default, from: from)
        set.call(["release_notes", "app_store", apple], line) if need_apple
        set.call(["release_notes", "play", play], line) if need_play
      end
    end

    # ────────────────────────────────── env ──────────────────────────────────

    def part_env
      cfg = config
      return report("skipped: store.yml is incomplete (./release.sh setup --only store)") unless cfg
      path = env_path
      have = env
      ios = cfg["ios"] == "true"
      android = cfg["android"] == "true"
      add = {}
      if !File.file?(path) &&
         !@ask.yes?(".env", "Set up ./release.sh --local on this Mac (a gitignored #{rel(path)} with the credentials)", true)
        return report("skipped: no #{rel(path)}, so ./release.sh --local cannot run here")
      end

      if ios
        env_asc(have, add)
        identity = Setup.run("security", "find-identity", "-v", "-p", "codesigning").to_s
        unless identity.include?("Apple Distribution") && identity.include?("(#{cfg['ios_team_id']})")
          report "no Apple Distribution identity of team #{cfg['ios_team_id']} in the login keychain: iOS cannot sign here (references/secrets.md)"
        end
      end
      if android
        # What release.sh --local looks at: the .env, then android/fastlane.
        own = have["GOOGLE_PLAY_JSON_KEY_PATH"] || have["PLAY_STORE_JSON_KEY"]
        own = own && File.expand_path(own, File.dirname(path))
        own = File.join(@project.app_dir, "android", "fastlane", "play-store-key.json") unless own && File.file?(own)
        unless File.file?(own)
          default = play_key
          key = @ask.file("GOOGLE_PLAY_JSON_KEY_PATH", "Google Play service-account JSON (the account's, so another app's works)",
                          default, from: default && "another app", optional: true)
          add["GOOGLE_PLAY_JSON_KEY_PATH"] = key unless key.empty?
        end
        cfg["android_key_properties"].empty? ? env_gradle_signing(have, add, cfg) : env_key_properties(cfg)
      end
      cfg["dart_defines"].split.each do |name|
        next unless Setup.blank?(have[name])
        value = @ask.secret(name, "#{name} (a --dart-define value)")
        add[name] = value unless value.empty?
      end
      review = @review_private
      if ios && review.nil? && Setup.blank?(Setup.dig(store_data, %w[app_review email])) && Setup.blank?(have["ASC_REVIEW_EMAIL"])
        review = { "email" => @ask.ask("ASC_REVIEW_EMAIL", "App Review contact email (store.yml leaves it empty)"),
                   "phone" => @ask.ask("ASC_REVIEW_PHONE", "App Review contact phone (+41...)") }
      end
      if review
        %w[first_name last_name email phone].each do |k|
          name = "ASC_REVIEW_#{k.upcase}"
          add[name] = review[k].to_s if Setup.blank?(have[name]) && !Setup.blank?(review[k])
        end
      end

      if add.empty?
        report "#{rel(path)} has what ./release.sh --local needs"
      else
        write_env(path, add) unless @ask.plan?
        report "#{rel(path)}: #{did('added', 'would add')} #{add.keys.join(', ')}"
      end
      report "WARNING: #{rel(path)} is not gitignored" if File.file?(path) && !@project.ignored?(rel(path))
    end

    def find_p8(key_id)
      return [nil, nil] if Setup.blank?(key_id)
      own = @others.envs.find { |_, e| e["ASC_KEY_ID"] == key_id && !Setup.blank?(e["ASC_KEY_PATH"]) }
      if own
        p = File.expand_path(own[1]["ASC_KEY_PATH"], File.dirname(own[0]))
        return [p, @others.label(own[0])] if File.file?(p)
      end
      KEY_DIRS.each do |d|
        p = File.expand_path("#{d}/AuthKey_#{key_id}.p8")
        return [p, d] if File.file?(p)
      end
      [nil, nil]
    end

    def env_asc(have, add)
      if Setup.blank?(have["ASC_KEY_ID"])
        id, from = Setup.most_common(@others.env_values("ASC_KEY_ID"))
        if id.nil?
          p8 = KEY_DIRS.flat_map { |d| Dir.glob(File.expand_path("#{d}/AuthKey_*.p8")) }.max_by { |f| File.mtime(f) }
          id, from = [p8[/AuthKey_(\w+)\.p8\z/, 1], File.dirname(p8)] if p8
        end
        add["ASC_KEY_ID"] = @ask.ask("ASC_KEY_ID", "App Store Connect API key id", id, from: from)
      end
      key_id = add["ASC_KEY_ID"] || have["ASC_KEY_ID"]
      if Setup.blank?(have["ASC_ISSUER_ID"])
        same = @others.envs.select { |_, e| e["ASC_KEY_ID"] == key_id }.map { |p, e| [e["ASC_ISSUER_ID"], @others.label(p)] }
        issuer, from = Setup.most_common(same.empty? ? @others.env_values("ASC_ISSUER_ID") : same)
        add["ASC_ISSUER_ID"] = @ask.ask("ASC_ISSUER_ID", "App Store Connect issuer id", issuer, from: from)
      end
      now = have["ASC_KEY_PATH"] && File.expand_path(have["ASC_KEY_PATH"], File.dirname(env_path))
      return if now && File.file?(now)
      default, from = find_p8(key_id)
      add["ASC_KEY_PATH"] = @ask.file("ASC_KEY_PATH", "The .p8 file of key #{key_id}", default, from: from)
    end

    # The upload keystore another app on this Mac signs with: path, alias and
    # (when the same keystore) its key.properties to take the passwords from.
    def keystore_default(alias_name)
      found = @others.key_properties.map do |p, kp|
        store = kp["storeFile"] && File.expand_path(kp["storeFile"], File.join(File.dirname(p), "app"))
        store = File.expand_path(kp["storeFile"], File.dirname(p)) unless store && File.file?(store)
        store && File.file?(store) ? [store, @others.label(p), kp] : nil
      end.compact
      path, from = Setup.most_common(found.map { |s, l, _| [s, l] })
      path ||= File.expand_path("~/upload-keystore.jks") if File.file?(File.expand_path("~/upload-keystore.jks"))
      donor = found.find { |s, _, kp| s == path && kp["keyAlias"].to_s == alias_name && !Setup.blank?(kp["storePassword"]) }
      [path, from, donor]
    end

    def env_key_properties(cfg)
      path = File.join(app_dir_abs, cfg["android_key_properties"])
      kp = Setup.properties(path)
      return if %w[storeFile storePassword keyPassword keyAlias].all? { |k| !Setup.blank?(kp[k]) }
      alias_name = cfg["android_key_alias"]
      default, from, donor = keystore_default(alias_name)
      store = @ask.file("storeFile", "The upload keystore (.jks) the Android app signs with", default, from: from)
      return report("skipped #{rel(path)}: no keystore, so Android cannot sign here") if store.empty?
      alias_name = @ask.ask("keyAlias", "Its key alias", alias_name)
      if donor && donor[0] == store && @ask.yes?("passwords", "Take the keystore's passwords from #{donor[1]} (same keystore)", true)
        store_pw, key_pw = donor[2]["storePassword"], donor[2]["keyPassword"]
      else
        store_pw = @ask.secret("storePassword", "Keystore password")
        key_pw = @ask.secret("keyPassword", "Key password (Enter: the same)")
        key_pw = store_pw if key_pw.empty?
      end
      return report("would write #{rel(path)}") if @ask.plan?
      unless keystore_opens?(store, store_pw, alias_name)
        return report("#{rel(path)} not written: the keystore did not open with that password and alias")
      end
      File.open(path, "w", 0o600) do |f|
        f.puts "storePassword=#{store_pw}", "keyPassword=#{key_pw}", "keyAlias=#{alias_name}", "storeFile=#{store}"
      end
      report "#{rel(path)}: written (signs with #{store}, alias #{alias_name})"
    end

    def env_gradle_signing(have, add, cfg)
      return if %w[KEYSTORE_PATH KEYSTORE_PASSWORD KEY_ALIAS KEY_PASSWORD].all? { |k| !Setup.blank?(have[k]) }
      default, from, donor = keystore_default(cfg["android_key_alias"])
      store = @ask.file("KEYSTORE_PATH", "The upload keystore (.jks) the Android app signs with", default, from: from)
      return if store.empty?
      alias_name = @ask.ask("KEY_ALIAS", "Its key alias", cfg["android_key_alias"])
      if donor && donor[0] == store && @ask.yes?("passwords", "Take the keystore's passwords from #{donor[1]} (same keystore)", true)
        store_pw, key_pw = donor[2]["storePassword"], donor[2]["keyPassword"]
      else
        store_pw = @ask.secret("KEYSTORE_PASSWORD", "Keystore password")
        key_pw = @ask.secret("KEY_PASSWORD", "Key password (Enter: the same)")
        key_pw = store_pw if key_pw.empty?
      end
      add.update("KEYSTORE_PATH" => store, "KEY_ALIAS" => alias_name, "KEYSTORE_PASSWORD" => store_pw, "KEY_PASSWORD" => key_pw)
    end

    def keystore_opens?(store, password, alias_name)
      return true if Setup.run("which", "keytool").nil?
      _, status = Open3.capture2e({ "SR_KS_PASS" => password }, "keytool", "-list", "-keystore", store,
                                  "-storepass:env", "SR_KS_PASS", "-alias", alias_name)
      status.success?
    end

    def write_env(path, add)
      fresh = !File.file?(path)
      text = fresh ? "# Credentials for ./release.sh --local. Gitignored: never commit this file.\n" : File.read(path)
      text += "\n" unless text.end_with?("\n")
      add.each do |k, v|
        v = "\"#{v}\"" if v =~ /[\s#"'$`\\]/ && !v.include?('"')
        text += "#{k}=#{v}\n"
      end
      File.write(path, text)
      File.chmod(0o600, path)
    end

    # ──────────────────────────────── listing ────────────────────────────────

    def part_listing
      cfg = config
      return report("skipped: store.yml is incomplete (./release.sh setup --only store)") unless cfg
      dir = File.join(app_dir_abs, cfg["listing_dir"])
      files = Dir.glob(File.join(dir, "*.md")).reject { |f| File.basename(f).upcase.start_with?("README") }
      unless files.empty?
        listing_languages(files.map { |f| File.basename(f, ".md") })
        return report("#{rel(dir)}/ has #{files.size} language#{files.size == 1 ? '' : 's'}: #{files.map { |f| File.basename(f, '.md') }.sort.join(', ')}")
      end
      found = lookup
      dump = @listing_json && File.file?(@listing_json) ? (JSON.parse(File.read(@listing_json)) rescue {}) : {}
      dump.delete("app_store") unless cfg["ios"] == "true"
      dump.delete("play") unless cfg["android"] == "true"
      stores = [dump["app_store"].to_h.any? && "App Store Connect", dump["play"].to_h.any? && "Google Play"].select { |s| s }
      if found && !stores.empty? &&
         @ask.yes?("listing", "Import the listing as #{stores.join(' and ')} #{stores.size == 1 ? 'has' : 'have'} it now into #{rel(dir)}/, one file per language", true)
        source = File.join(@tmp, "import.json")
        File.write(source, JSON.generate(dump))
      elsif @ask.yes?("listing", "Create #{rel(dir)}/en.md with the listing's fields, empty, to fill in", true)
        skeleton = {}
        skeleton["app_store"] = { "en-US" => {} } if cfg["ios"] == "true"
        skeleton["play"] = { "en-US" => {} } if cfg["android"] == "true"
        source = File.join(@tmp, "skeleton.json")
        File.write(source, JSON.generate(skeleton))
      else
        return report("no listing yet: ./release.sh listing sends listing/<language>.md once it exists")
      end
      return report("would write #{rel(dir)}/") if @ask.plan?
      # store.yml's URLs, so a language whose URL differs keeps its own.
      urls = %w[support_url privacy_url marketing_url].map { |k| ["SR_LISTING_#{k.upcase}", cfg["listing_#{k}"].to_s] }.to_h
      out, = Open3.capture2e(urls, "python3", File.join(DIR, "listing.py"), "--from-json", source, dir)
      unknown = []
      out.each_line do |line|
        if line.start_with?("language\t")
          unknown << line.strip.split("\t")[1..3]
        else
          puts line.sub(@root + "/", "")
        end
      end
      add_languages(unknown)
      report "#{rel(dir)}/: written; check every field, then ./release.sh listing --dry-run"
    end

    # A listing file whose language code the table lacks needs its two store
    # locales in store.yml.
    def listing_languages(codes)
      known = Setup.dig(store_data, %w[listing languages]) || {}
      unknown = codes.reject { |c| locales.key?(c) || known.key?(c) }.map do |c|
        [c, @ask.ask("listing.languages.#{c}", "App Store locale of #{c}.md", c),
         @ask.ask("listing.languages.#{c}", "Google Play locale of #{c}.md", c)]
      end
      add_languages(unknown)
    end

    def add_languages(entries)
      return if entries.empty? || @ask.plan?
      y = YamlText.new(File.read(store_path, encoding: "UTF-8"))
      entries.each do |code, apple, play|
        y.set(["listing", "languages", code, "app_store"], apple)
        y.set(["listing", "languages", code, "play"], play)
      end
      File.write(store_path, y.to_s)
      @store_data = nil
      report "store.yml listing.languages: #{entries.map(&:first).join(', ')}"
    end

    # ──────────────────────────────── secrets ────────────────────────────────

    def part_secrets
      cfg = config
      return report("skipped: store.yml is incomplete (./release.sh setup --only store)") unless cfg
      slug = @project.github_slug
      return report("skipped: origin is not a GitHub repository") unless slug
      return report("skipped: gh is not installed") if Setup.run("which", "gh").nil?
      if Setup.run("gh", "api", "repos/#{slug}", "--jq", ".full_name").nil?
        return report("skipped: the active gh account cannot see #{slug} (gh auth switch)")
      end
      existing = Setup.run("gh", "secret", "list", "--repo", slug, "--env", "production", "--json", "name",
                           "--jq", ".[].name").to_s.split("\n")
      ios = cfg["ios"] == "true"
      android = cfg["android"] == "true"
      data = store_data
      needed = []
      needed += SECRETS_IOS if ios
      needed += SECRETS_ANDROID if android
      needed << "DART_DEFINES_JSON" unless cfg["dart_defines"].empty?
      if ios
        %w[first_name last_name email phone].each do |k|
          needed << "APP_REVIEW_#{k.upcase}" if Setup.blank?(Setup.dig(data, ["app_review", k]))
        end
      end
      missing = needed - existing
      if missing.empty?
        report "#{slug} has every secret a release needs"
        return
      end
      report "#{slug} lacks #{missing.join(', ')}"
      lines, args = secrets_values(missing, cfg)
      file = File.join(@tmp, "secrets.local.env")
      File.open(file, "w", 0o600) { |f| lines.each { |k, v| f.puts "#{k}=#{v}" } }
      return if @ask.plan?
      cmd = [File.join(DIR, "secrets.sh"), "--repo", slug, "--only-missing", "--file", file] + args
      system(*cmd) or report("secrets.sh did not finish; run ./release.sh setup --only secrets again")
    end

    # The values secrets.sh needs for what is missing: [file lines, arguments].
    def secrets_values(missing, cfg)
      lines = {}
      args = []
      have = env
      env_file = File.file?(env_path) ? env_path : nil
      asc_names = %w[APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_B64]
      unless (missing & asc_names).empty?
        id, from = Setup.blank?(have["ASC_KEY_ID"]) ? Setup.most_common(@others.env_values("ASC_KEY_ID")) : [have["ASC_KEY_ID"], rel(env_path)]
        id = @ask.ask("APP_STORE_CONNECT_API_KEY_ID", "App Store Connect key id for GitHub (it may be another key than this Mac's)",
                      id, from: from)
        same = @others.envs.select { |_, e| e["ASC_KEY_ID"] == id }.map { |p, e| [e["ASC_ISSUER_ID"], @others.label(p)] }
        issuer, from = have["ASC_KEY_ID"] == id ? [have["ASC_ISSUER_ID"], rel(env_path)] : Setup.most_common(same)
        lines["APP_STORE_CONNECT_API_KEY_ID"] = id
        lines["APP_STORE_CONNECT_ISSUER_ID"] = @ask.ask("APP_STORE_CONNECT_ISSUER_ID", "Its issuer id", issuer, from: from)
        p8, from = find_p8(id)
        lines["APP_STORE_CONNECT_API_KEY_P8"] = @ask.file("APP_STORE_CONNECT_API_KEY_P8", "Its .p8 file", p8, from: from)
      end
      unless (missing & %w[APPLE_DISTRIBUTION_P12_B64 APPLE_DISTRIBUTION_P12_PASSWORD]).empty?
        candidates = (KEY_DIRS.map { |d| "#{d}/*.p12" } + ["~/git/*/keys/*.p12", "~/git/*/*/keys/*.p12"])
                     .flat_map { |g| Dir.glob(File.expand_path(g)) }
        p12 = candidates.max_by { |f| File.mtime(f) }
        lines["APPLE_DISTRIBUTION_P12"] = @ask.file("APPLE_DISTRIBUTION_P12", "The Apple Distribution certificate with its private key (.p12)",
                                                    p12, from: p12 && "newest .p12 found")
        lines["APPLE_DISTRIBUTION_P12_PASSWORD"] = @ask.secret("APPLE_DISTRIBUTION_P12_PASSWORD", "Its password")
      end
      if missing.include?("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")
        key = play_key
        lines["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"] = @ask.file("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "Google Play service-account JSON",
                                                              key, from: key && "this app's .env")
      end
      unless (missing & %w[ANDROID_KEYSTORE_B64 ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_PASSWORD]).empty?
        kp = cfg["android_key_properties"].empty? ? nil : File.join(app_dir_abs, cfg["android_key_properties"])
        if kp && File.file?(kp)
          args += ["--from-key-properties", kp]
        elsif !Setup.blank?(have["KEYSTORE_PATH"])
          lines["ANDROID_KEYSTORE"] = File.expand_path(have["KEYSTORE_PATH"], File.dirname(env_path))
          lines["ANDROID_KEYSTORE_PASSWORD"] = have["KEYSTORE_PASSWORD"]
          lines["ANDROID_KEY_PASSWORD"] = have["KEY_PASSWORD"]
        else
          default, from = keystore_default(cfg["android_key_alias"])
          lines["ANDROID_KEYSTORE"] = @ask.file("ANDROID_KEYSTORE", "The upload keystore (.jks)", default, from: from)
          lines["ANDROID_KEYSTORE_PASSWORD"] = @ask.secret("ANDROID_KEYSTORE_PASSWORD", "Keystore password")
          lines["ANDROID_KEY_PASSWORD"] = @ask.secret("ANDROID_KEY_PASSWORD", "Key password")
        end
      end
      if missing.include?("DART_DEFINES_JSON")
        names = cfg["dart_defines"].split
        names.each do |n|
          next unless Setup.blank?(have[n])
          lines[n] = @ask.secret(n, "#{n} (a --dart-define value)")
        end
        args += ["--dart-defines", names.join(",")]
      end
      review = @review_private || {}
      %w[first_name last_name email phone].each do |k|
        name = "APP_REVIEW_#{k.upcase}"
        next unless missing.include?(name)
        value = review[k] || have["ASC_REVIEW_#{k.upcase}"]
        lines[name] = Setup.blank?(value) ? @ask.ask(name, "App Review contact: #{k.tr('_', ' ')}") : value
      end
      args += ["--from-env", env_file] if env_file
      secret_files.each { |spec| args += ["--secret-file", spec] }
      [lines.reject { |_, v| Setup.blank?(v) }, args]
    end

    # Files the build reads that the repository leaves out, asked once.
    def secret_files
      return [] if @secret_files_asked
      @secret_files_asked = true
      existing = Setup.run("gh", "secret", "list", "--repo", @project.github_slug.to_s, "--env", "production",
                           "--json", "name", "--jq", ".[].name").to_s.split("\n")
      return [] if existing.include?("APP_SECRET_FILES_JSON")
      app = app_dir_abs
      SECRET_FILE_CANDIDATES.select do |r|
        path = File.join(app, r)
        File.file?(path) && !@project.tracked?(path) &&
          @ask.yes?("APP_SECRET_FILES_JSON", "#{r} is here but not in the repository, so a runner's build has none: send it along as a secret", true)
      end.map { |r| "#{r}=#{File.join(app, r)}" }
    end

    # ───────────────────────────────── the end ─────────────────────────────────

    def finish
      if @plan
        @report.each { |part, text| puts "#{part}: #{text}" }
        if @ask.pending.empty?
          puts "Nothing to ask: this app has what a release needs."
          exit 0
        end
        puts "\nIt would ask (./release.sh setup, in a terminal):"
        width = @ask.pending.map { |_, k, _, _| k.length }.max
        @ask.pending.each do |part, key, default, from|
          puts format("  %-8s %-#{width}s  %s%s", part, key, default, from ? "  (#{from})" : "")
        end
        exit 10
      end
      puts "\nNext: ./release.sh --dry-run (on GitHub) or ./release.sh --local --dry-run (on this Mac)."
    end
  end
end

Setup::Run.new(ARGV.dup).call if $PROGRAM_NAME == __FILE__
