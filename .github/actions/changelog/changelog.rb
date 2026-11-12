#!/usr/bin/env ruby
# frozen_string_literal: true

# The changelog and the store facts behind a release. CI runs this through
# action.yml next to it; a release from a laptop uses the same file (a Fastfile
# requires it, deploy.sh runs it), so both count versions the same way.
#
# The changelog:
#
#   ## Next
#
#   ### Public
#   - What users notice, in their words. Only when it is worth telling them.
#
#   ### Internal
#   - Everything that changed and matters, for the team.
#
#   ## 1.18.0 (2026-11-11)
#   ...
#
# `## Next` carries no number. A release ships it as the newest released
# version plus one minor (or patch, or major), turns it into `## X.Y.Z (date)`
# and opens an empty `## Next` above it. The stores get `### Public`; when that
# is empty, store.yml's release_notes.default. Sections written before this
# convention, without `###` subsections, count as Public.
#
#   changelog.rb version [--changelog FILE] [--bump minor|patch|major]
#   changelog.rb notes   [--changelog FILE] [--store FILE]
#   changelog.rb check   [--changelog FILE]
#   changelog.rb release --version X.Y.Z [--changelog FILE] [--released-ref REF] [--date YYYY-MM-DD]
#   changelog.rb store   [--store FILE]          store.yml as one line of JSON
#
# Exit codes: 0 fine, 1 check found problems, 2 anything else wrong,
# 3 nothing to release (## Next is empty).

require "date"
require "json"
require "open3"
require "optparse"
require "yaml"

module Changelog
  class Error < StandardError; end
  class NothingToRelease < Error; end

  DEFAULT_NOTES = "Bug fixes and improvements."
  SUBSECTIONS = %w[public internal].freeze
  NEXT_HEADING = /\A##\s+Next\b/i.freeze
  VERSION_HEADING = /\A##\s+v?(\d+)\.(\d+)\.(\d+)(?:\s|\z)/.freeze
  SUBSECTION_HEADING = /\A###\s+(.+?)\s*\z/.freeze
  # Apple refuses emoji in What's New, and the App Store Connect API rejects
  # the whole request for one.
  EMOJI = /[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]/.freeze
  # House style for anything users read: a colon, comma or period instead.
  LONG_DASH = /[–—]/.freeze
  PLAY_LIMIT = 500
  REVIEW_KEYS = %w[first_name last_name email phone].freeze

  Section = Struct.new(:heading, :lines) do
    def next?
      NEXT_HEADING.match?(heading)
    end

    def version
      m = VERSION_HEADING.match(heading)
      m && m.captures.map(&:to_i)
    end

    # { nil => lines before any ###, "public" => [...], "internal" => [...] }
    def parts
      result = { nil => [] }
      current = nil
      lines.each do |line|
        if (m = SUBSECTION_HEADING.match(line))
          current = m[1].downcase
          result[current] ||= []
        else
          result[current] << line
        end
      end
      result
    end

    def subsections?
      parts.keys.compact.any?
    end

    # Public and Internal; an old section without subsections is all Public.
    # Stray lines in a section that has subsections count as Internal, so
    # nothing unchecked ever reaches a store.
    def normalized
      p = parts
      return { "public" => p[nil], "internal" => [] } unless subsections?

      { "public" => p["public"] || [], "internal" => (p["internal"] || []) + p[nil] }
    end

    def empty?
      lines.none? { |l| !l.strip.empty? && !SUBSECTION_HEADING.match?(l) }
    end
  end

  module_function

  def parse(text)
    preamble = []
    sections = []
    text.each_line(chomp: true) do |line|
      if line.start_with?("## ")
        sections << Section.new(line, [])
      elsif sections.empty?
        preamble << line
      else
        sections.last.lines << line
      end
    end
    [preamble, sections]
  end

  def load(path)
    raise Error, "#{path} does not exist" unless File.file?(path)

    parse(File.read(path, encoding: "UTF-8"))
  end

  def trimmed(lines)
    l = lines.dup
    l.shift while l.first && l.first.strip.empty?
    l.pop while l.last && l.last.strip.empty?
    l
  end

  def next_section(sections, path)
    sections.find(&:next?) or raise Error, "#{path} has no '## Next' section"
  end

  def released_versions(sections)
    sections.map(&:version).compact
  end

  # The version ## Next ships as.
  def next_version(path, bump: "minor")
    _, sections = load(path)
    nxt = next_section(sections, path)
    raise NothingToRelease, "nothing to release: '## Next' in #{path} is empty" if nxt.empty?

    latest = released_versions(sections).max or
      raise Error, "#{path} has no released version (## X.Y.Z) to count on from"
    major, minor, patch = latest
    case bump
    when "major" then [major + 1, 0, 0]
    when "minor" then [major, minor + 1, 0]
    when "patch" then [major, minor, patch + 1]
    else raise Error, "bump is major, minor or patch, not '#{bump}'"
    end.join(".")
  end

  # What the stores get for ## Next.
  def store_notes(path, store_path = nil)
    _, sections = load(path)
    nxt = next_section(sections, path)
    raise NothingToRelease, "nothing to release: '## Next' in #{path} is empty" if nxt.empty?

    notes = trimmed(nxt.normalized["public"]).join("\n")
    return notes unless notes.strip.empty?

    default = store(store_path).dig("release_notes", "default").to_s.strip
    default.empty? ? DEFAULT_NOTES : default
  end

  # Play's What's new: whole lines from the top, plus the last line, within
  # limit; cut at a word only when not even one line fits. The workflow does
  # the same in Python.
  def fit(text, limit = PLAY_LIMIT)
    return text if text.length <= limit

    lines = text.lines.map(&:chomp).reject { |l| l.strip.empty? }
    last = lines.pop
    kept = []
    lines.each do |line|
      break if (kept + [line, last]).join("\n").length > limit

      kept << line
    end
    fitted = (kept + [last]).join("\n")
    return fitted if fitted.length <= limit

    cut = text[0, limit - 3]
    "#{cut[0, cut.rindex(' ') || cut.length]}..."
  end

  # [errors, warnings] for ## Next.
  def check(path)
    _, sections = load(path)
    errors = []
    warnings = []
    nexts = sections.select(&:next?)
    errors << "no '## Next' section" if nexts.empty?
    errors << "#{nexts.size} '## Next' sections; there is one" if nexts.size > 1
    errors << "'## Next' is not the first section" if nexts.any? && !sections.first.next?
    nxt = nexts.first
    return [errors, warnings] unless nxt

    if nxt.heading =~ /\d+\.\d+\.\d+/
      errors << "'#{nxt.heading}': '## Next' carries no version; the release counts it from the last ## X.Y.Z"
    end
    parts = nxt.parts
    unknown = parts.keys.compact - SUBSECTIONS
    unless unknown.empty?
      errors << "under '## Next' only '### Public' and '### Internal', not: #{unknown.map { |u| "### #{u}" }.join(', ')}"
    end
    loose = parts[nil].reject { |l| l.strip.empty? }
    errors << "under '## Next' but outside '### Public' and '### Internal': #{loose.first.strip}" if !loose.empty? && nxt.subsections?
    errors << "'## Next' has no '### Public' and '### Internal' subsections" if !loose.empty? && !nxt.subsections?
    nxt.lines.each { |l| errors << "emoji (the App Store refuses them): #{l.strip}" if EMOJI.match?(l) }
    public_lines = nxt.normalized["public"]
    public_lines.each do |l|
      errors << "long dash in Public (a colon, comma or period instead): #{l.strip}" if LONG_DASH.match?(l)
    end
    public = trimmed(public_lines).join("\n")
    if public.length > PLAY_LIMIT
      warnings << "Public is #{public.length} characters; Play shows whole lines from the top plus the last one within #{PLAY_LIMIT}"
    end
    [errors, warnings]
  end

  # ## Next becomes ## VERSION (DATE) and an empty ## Next opens above it.
  # With released_ref, only what ## Next held at that commit moves: lines
  # added while the release ran stay under ## Next.
  def release(path, version, released_ref: nil, date: Date.today)
    raise Error, "'#{version}' is not X.Y.Z" unless /\A\d+\.\d+\.\d+\z/.match?(version)

    preamble, sections = load(path)
    if released_versions(sections).include?(version.split(".").map(&:to_i))
      raise Error, "#{path} already has a ## #{version} section"
    end

    nxt = next_section(sections, path)
    shipped = released_ref ? next_section(parse(git_show(path, released_ref))[1], "#{path} at #{released_ref}") : nxt
    raise NothingToRelease, "nothing to release: '## Next' is empty" if shipped.empty?

    shipped_parts = shipped.normalized
    left = {}
    nxt.normalized.each do |name, lines|
      rest = lines.dup
      shipped_parts[name].each do |line|
        next if line.strip.empty?

        i = rest.index(line)
        rest.delete_at(i) if i
      end
      left[name] = rest
    end

    index = sections.index(nxt)
    sections[index, 1] = [
      Section.new("## Next", body(left, keep_empty: true)),
      Section.new("## #{version} (#{date.iso8601})", body(shipped_parts, keep_empty: false))
    ]
    File.write(path, render(preamble, sections))
  end

  def body(parts, keep_empty:)
    lines = [""]
    SUBSECTIONS.each do |name|
      content = trimmed(parts[name] || [])
      next if content.empty? && !keep_empty

      lines << "### #{name.capitalize}"
      lines.concat(content)
      lines << ""
    end
    lines
  end

  def render(preamble, sections)
    out = preamble.dup
    sections.each do |s|
      out << s.heading
      out.concat(s.lines)
    end
    "#{trimmed(out).join("\n")}\n"
  end

  def git_show(path, ref)
    dir, base = File.split(File.expand_path(path))
    out, err, status = Open3.capture3("git", "-C", dir, "show", "#{ref}:./#{base}")
    raise Error, "git show #{ref}:#{path} failed: #{err.strip}" unless status.success?

    out
  end

  # store.yml as a Hash; {} when there is none.
  def store(path)
    return {} if path.nil? || path.empty? || !File.file?(path)

    data = YAML.safe_load(File.read(path, encoding: "UTF-8")) || {}
    raise Error, "#{path} is not a YAML mapping" unless data.is_a?(Hash)

    phone = data.dig("app_review", "phone")
    if phone.is_a?(Numeric)
      raise Error, "#{path}: put app_review.phone in quotes; unquoted, YAML reads it as a number and drops the +"
    end

    data
  end

  # { "first_name" => ..., "last_name" => ..., "email" => ..., "phone" => ... }
  # from store.yml, any empty value taken from fallback (a Hash with the same
  # keys, e.g. from .env or GitHub secrets). nil when nothing is set; an error
  # when only some of it is.
  def review_contact(store_data, fallback = {})
    review = store_data["app_review"] || {}
    contact = REVIEW_KEYS.map do |k|
      value = review[k].to_s.strip
      value = fallback[k].to_s.strip if value.empty?
      [k, value]
    end.to_h
    return nil if contact.values.all?(&:empty?)

    missing = contact.select { |_, v| v.empty? }.keys
    raise Error, "the App Review contact lacks #{missing.join(', ')} (store.yml app_review)" unless missing.empty?

    contact
  end
end

if $PROGRAM_NAME == __FILE__
  def fail_with(message, code)
    if ENV["GITHUB_ACTIONS"] == "true"
      puts "::error::#{message}"
    else
      warn "changelog: #{message}"
    end
    exit code
  end

  command = ARGV.shift
  opts = { changelog: "CHANGELOG.md", bump: "minor", store: nil }
  begin
    OptionParser.new do |o|
      o.on("--changelog FILE") { |v| opts[:changelog] = v }
      o.on("--store FILE") { |v| opts[:store] = v }
      o.on("--bump KIND") { |v| opts[:bump] = v }
      o.on("--version X.Y.Z") { |v| opts[:version] = v }
      o.on("--released-ref REF") { |v| opts[:released_ref] = v }
      o.on("--date YYYY-MM-DD") { |v| opts[:date] = Date.iso8601(v) }
    end.parse!(ARGV)

    case command
    when "version"
      puts Changelog.next_version(opts[:changelog], bump: opts[:bump])
    when "notes"
      puts Changelog.store_notes(opts[:changelog], opts[:store])
    when "check"
      errors, warnings = Changelog.check(opts[:changelog])
      gha = ENV["GITHUB_ACTIONS"] == "true"
      warnings.each { |w| gha ? puts("::warning::#{opts[:changelog]}: #{w}") : warn("warning: #{w}") }
      errors.each { |e| gha ? puts("::error::#{opts[:changelog]}: #{e}") : warn("error: #{e}") }
      exit(errors.empty? ? 0 : 1)
    when "release"
      fail_with("release needs --version X.Y.Z", 2) unless opts[:version]
      Changelog.release(opts[:changelog], opts[:version],
                        released_ref: opts[:released_ref], date: opts[:date] || Date.today)
      puts "#{opts[:changelog]}: ## Next is now ## #{opts[:version]}, and a new ## Next is open."
    when "store"
      puts JSON.generate(Changelog.store(opts[:store]))
    else
      fail_with("usage: changelog.rb version|notes|check|release|store [options]", 2)
    end
  rescue Changelog::NothingToRelease => e
    fail_with(e.message, 3)
  rescue Changelog::Error, OptionParser::ParseError, ArgumentError, Psych::Exception => e
    fail_with(e.message, 2)
  end
end
