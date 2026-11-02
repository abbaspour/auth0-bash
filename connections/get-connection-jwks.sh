#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-10-28
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
#
# Fetches a connection's public JWKS (signing and encryption keys) from
#   https://${domain}/oauth/connection/${connection_name}/.well-known/jwks.json
##########################################################################################

set -ueo pipefail

DIR="${BASH_SOURCE[0]%/*}"
[ "$DIR" = "${BASH_SOURCE[0]}" ] && DIR="."
readonly DIR

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null   || { echo >&2 "error: jq not found";    exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-n connection_name] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -n name        # connection name
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -n my-oidc-connection
     $0 -d login.example.com -n my-okta-connection
END
    exit "$1"
}

declare DOMAIN=''
declare connection_name=''
declare -i opt_verbose=0

while getopts ":e:t:d:n:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    t) DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
    d) DOMAIN=${OPTARG} ;;
    n) connection_name=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h) usage 0 ;;
    \?) [[ "${OPTARG}" == "?" ]] && usage 0
        echo >&2 "ERROR: illegal option -- ${OPTARG}"
        usage 1 ;;
    :) echo >&2 "ERROR: option requires an argument -- ${OPTARG}"; usage 1 ;;
    esac
done

[[ -z "${DOMAIN}" ]]          && { echo >&2 "ERROR: DOMAIN undefined";          usage 1; }
[[ -z "${connection_name}" ]] && { echo >&2 "ERROR: connection_name undefined"; usage 1; }

[[ ${DOMAIN} =~ ^http ]] || DOMAIN="https://${DOMAIN}"
[[ ${DOMAIN} =~ /$ ]]    || DOMAIN="${DOMAIN}/"

encoded_name=$(jq -rn --arg n "${connection_name}" '$n | @uri')
readonly encoded_name

readonly JWKS_URL="${DOMAIN}oauth/connection/${encoded_name}/.well-known/jwks.json"

[[ ${opt_verbose} -eq 1 ]] && echo >&2 "GET ${JWKS_URL}"

response=$(curl -s --write-out '\n%{http_code}' --url "${JWKS_URL}")
readonly response

readonly http_code="${response##*$'\n'}"
readonly body="${response%$'\n'*}"

[[ "${http_code}" == "200" ]] || { echo >&2 "ERROR: HTTP ${http_code} from ${JWKS_URL}"; echo >&2 "${body}"; exit 1; }

jq . <<< "${body}"
