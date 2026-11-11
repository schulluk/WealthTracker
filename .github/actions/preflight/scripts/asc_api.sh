# shellcheck shell=bash
# App Store Connect API helpers. Source this file.
#
# Needs APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_ISSUER_ID and a .p8 at
# $ASC_KEY_PATH. Plain bash 3.2 and ruby's stdlib: the preflight job installs
# no gems.

ASC_API_ATTEMPTS="${ASC_API_ATTEMPTS:-3}"
# Overridable only so the scripts can be exercised against a local mock.
ASC_API_BASE="${ASC_API_BASE:-https://api.appstoreconnect.apple.com}"

generate_asc_jwt() {
  # Ruby, because ES256 needs the DER signature converted to P1363 and
  # openssl(1) will not do it.
  ruby -e '
    require "base64"
    require "openssl"
    require "json"

    key_id = ENV.fetch("APP_STORE_CONNECT_API_KEY_ID")
    issuer_id = ENV.fetch("APP_STORE_CONNECT_ISSUER_ID")
    key = OpenSSL::PKey::EC.new(File.read(ENV.fetch("ASC_KEY_PATH")))

    b64 = ->(data) { Base64.urlsafe_encode64(data, padding: false) }
    now = Time.now.to_i
    signing_input = [
      b64.(JSON.dump(alg: "ES256", kid: key_id, typ: "JWT")),
      b64.(JSON.dump(iss: issuer_id, iat: now, exp: now + 1200, aud: "appstoreconnect-v1")),
    ].join(".")

    der = key.sign(OpenSSL::Digest::SHA256.new, signing_input)
    asn1 = OpenSSL::ASN1.decode(der)
    r = asn1.value[0].value.to_s(2).rjust(32, "\0")
    s = asn1.value[1].value.to_s(2).rjust(32, "\0")
    puts "#{signing_input}.#{b64.(r + s)}"
  '
}

# asc_api METHOD PATH [JSON_BODY]
#
# Prints the body on success. On HTTP >= 400 prints the response on stderr,
# puts it in ASC_LAST_ERROR and returns 1. GET and PATCH are retried on
# network errors, 429 and 5xx; POST and DELETE are not, because after a
# timeout the server may already have acted.
asc_api() {
  local method="$1" path="$2" body="${3:-}"
  local jwt
  jwt=$(generate_asc_jwt) || true
  if [ -z "$jwt" ]; then
    ASC_LAST_ERROR="could not sign a JWT with the given key"
    echo "::error::App Store Connect: $ASC_LAST_ERROR. Is APP_STORE_CONNECT_API_KEY_P8_B64 the whole .p8 file, BEGIN and END lines included?" >&2
    return 1
  fi
  local args=(-s --globoff --connect-timeout 10 --max-time 60
    -H "Authorization: Bearer $jwt" -H "Content-Type: application/json" -w "\n%{http_code}")
  case "$method" in
    POST) args+=(-X POST); [ -n "$body" ] && args+=(-d "$body") ;;
    PATCH) args+=(-X PATCH); [ -n "$body" ] && args+=(-d "$body") ;;
    DELETE) args+=(-X DELETE) ;;
  esac
  local attempts=1
  case "$method" in GET | PATCH) attempts="$ASC_API_ATTEMPTS" ;; esac

  local attempt raw http_code body_text
  for attempt in $(seq 1 "$attempts"); do
    raw=$(curl "${args[@]}" "${ASC_API_BASE}${path}") || raw=$'\n000'
    http_code=$(echo "$raw" | tail -1)
    body_text=$(echo "$raw" | sed '$d')
    case "$http_code" in
      000 | 429 | 5??)
        if [ "$attempt" -lt "$attempts" ]; then
          sleep $((attempt * 5))
          continue
        fi
        ;;
    esac
    break
  done
  # Read by the caller: preflight.sh tells a 403, which is what an
  # outstanding agreement looks like, from any other refusal.
  # shellcheck disable=SC2034
  ASC_LAST_STATUS="$http_code"
  if ! [ "$http_code" -ge 200 ] 2>/dev/null || [ "$http_code" -ge 400 ]; then
    ASC_LAST_ERROR="HTTP $http_code: $body_text"
    echo "ASC $method $path -> $ASC_LAST_ERROR" >&2
    return 1
  fi
  [ "$method" = "DELETE" ] && return 0
  echo "$body_text"
}
