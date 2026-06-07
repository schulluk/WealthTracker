#!/usr/bin/env ruby
# Bump CHANGELOG.md to the next minor version after a successful submit.
#
# Invoked by deploy.sh after both iOS and Android `submit` lanes succeed,
# so the changelog is already pointing at the next in-development version
# the next time `beta` is run.

changelog_path = File.expand_path("../CHANGELOG.md", __dir__)
abort("CHANGELOG.md not found at #{changelog_path}") unless File.exist?(changelog_path)

content = File.read(changelog_path)

match = content.match(/^## Next:?\s+(\d+)\.(\d+)\.(\d+)(\s*!)?\s*$/)
unless match
  abort("No '## Next: X.Y.Z' heading found in #{changelog_path}")
end

major = match[1].to_i
minor = match[2].to_i
patch = match[3].to_i
current = "#{major}.#{minor}.#{patch}"
new_version = "#{major}.#{minor + 1}.0"

content.sub!(
  /^## Next:?\s+#{Regexp.escape(current)}(\s*!)?\s*$/,
  "## Next: #{new_version}\n\n- Bug fixes and improvements.\n\n## #{current}"
)

File.write(changelog_path, content)
puts "CHANGELOG.md bumped: #{current} -> #{new_version}"
