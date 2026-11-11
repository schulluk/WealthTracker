# Checks that the Play service account can open an edit for each package —
# the first thing every upload and every promotion does. That one call covers
# a revoked key, a read-only grant (edits.insert answers 403), an app the
# account was never granted, and a package that does not exist. The edit is
# deleted again, so nothing is changed.
#
# Usage: GOOGLE_PLAY_JSON_KEY_PATH=... ruby play_check.rb PACKAGE...
#
# One JSON line per package:
#   {"package":…,"result":"ok","tracks":["internal",…]}
#   {"package":…,"result":"blocked","reason":…}   4xx: about this app, retrying will not help
#   {"package":…,"result":"error","reason":…}     still failing after retries
# Exit 2 when no access token can be had at all, i.e. the key itself is bad.
#
# Standard library only: the preflight job installs no gems.

require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

ATTEMPTS = 3
# Overridable only so the script can be exercised against a local mock.
API = ENV.fetch('PLAY_API_BASE', 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications')

def transient?(res)
  res.code == '429' || res.code.start_with?('5')
end

# Retries network errors, 429 and 5xx. Returns the last response; raises the
# last network error.
def request(method, url, token: nil, form: nil, json: nil)
  uri = URI(url)
  ATTEMPTS.times do |attempt|
    last = attempt == ATTEMPTS - 1
    begin
      req = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(method).new(uri)
      req['Authorization'] = "Bearer #{token}" if token
      if form
        req.set_form_data(form)
      elsif json
        req['Content-Type'] = 'application/json'
        req.body = JSON.dump(json)
      end
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                open_timeout: 10, read_timeout: 30) do |http|
        http.request(req)
      end
      return res if last || !transient?(res)
    rescue StandardError
      raise if last
    end
    sleep((attempt + 1) * 5)
  end
end

def message(res)
  JSON.parse(res.body).dig('error', 'message') || res.body.to_s[0, 300]
rescue StandardError
  res.body.to_s[0, 300]
end

key = JSON.parse(File.read(ENV.fetch('GOOGLE_PLAY_JSON_KEY_PATH')))
token_uri = key['token_uri'] || 'https://oauth2.googleapis.com/token'
now = Time.now.to_i
b64 = ->(data) { Base64.urlsafe_encode64(data, padding: false) }
signing_input = [
  b64.(JSON.dump(alg: 'RS256', typ: 'JWT')),
  b64.(JSON.dump(iss: key['client_email'], scope: 'https://www.googleapis.com/auth/androidpublisher',
                 aud: token_uri, iat: now, exp: now + 600)),
].join('.')
signature = OpenSSL::PKey::RSA.new(key['private_key']).sign(OpenSSL::Digest.new('SHA256'), signing_input)

begin
  res = request(:post, token_uri, form: {
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: "#{signing_input}.#{b64.(signature)}",
  })
rescue StandardError => e
  warn "Google refused to issue an access token: #{e.message}"
  exit 2
end
unless res.is_a?(Net::HTTPSuccess)
  warn "Google refused to issue an access token: HTTP #{res.code} #{message(res)}"
  exit 2
end
token = JSON.parse(res.body).fetch('access_token')

ARGV.each do |package|
  result =
    begin
      res = request(:post, "#{API}/#{package}/edits", token: token, json: {})
      if res.is_a?(Net::HTTPSuccess)
        edit_id = JSON.parse(res.body).fetch('id')
        tracks =
          begin
            tr = request(:get, "#{API}/#{package}/edits/#{edit_id}/tracks", token: token)
            tr.is_a?(Net::HTTPSuccess) ? JSON.parse(tr.body).fetch('tracks', []).map { |t| t['track'] } : []
          rescue StandardError
            []
          end
        begin
          request(:delete, "#{API}/#{package}/edits/#{edit_id}", token: token)
        rescue StandardError
          # An abandoned edit expires on its own; no reason to fail.
        end
        { result: 'ok', tracks: tracks }
      elsif transient?(res)
        { result: 'error', reason: "Google Play HTTP #{res.code}: #{message(res)}" }
      else
        { result: 'blocked', reason: "Google Play refused access (HTTP #{res.code}): #{message(res)}" }
      end
    rescue StandardError => e
      { result: 'error', reason: "Google Play unreachable: #{e.message}" }
    end
  puts JSON.dump({ package: package }.merge(result))
end
