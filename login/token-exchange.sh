#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare AUTH0_SCOPE='openid profile email'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-x client_secret] [-i subject_token] [-T type] [-a audience] [-s scope] [-I|-h|-v]
        -e file               # .env file location (default cwd)
        -t tenant             # Auth0 tenant@region
        -d domain             # Auth0 domain
        -c client_id          # Auth0 client ID
        -x secret             # Auth0 client secret
        -i subject_token      # Subject token
        -T type               # subject_token type, e.g. http://acme.com/legacy-token
        -A audience           # Audience
        -s scopes             # comma separated list of scopes (default is "${AUTH0_SCOPE}")
        -I                    # mark subject_token is id_token
        -h|?                  # usage
        -v                    # verbose

eg,
     $0 -t amin01@au -c client_id -x client_secret -t ey... -a newapi -s read:things
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CLIENT_SECRET=''
declare AUTH0_AUDIENCE=''

declare subject_token=''
declare subject_token_type='access_token'

declare opt_verbose=0

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:t:d:c:x:A:i:a:T:s:Ihv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    x) AUTH0_CLIENT_SECRET=${OPTARG} ;;
    A) AUTH0_AUDIENCE=${OPTARG} ;;
    i) subject_token=${OPTARG} ;;
    T) subject_token_type=${OPTARG} ;;
    s) AUTH0_SCOPE=$(echo "${OPTARG}" | tr ',' ' ') ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined";  usage 1; }

[[ -z "${subject_token_type}" ]] && { echo >&2 "ERROR: subject_token_type undefined";  usage 1; }
[[ -z "${subject_token}" ]] && { echo >&2 "ERROR: subject_token undefined";  usage 1; }

declare secret=''
[[ -n "${AUTH0_CLIENT_SECRET}" ]] && secret="\"client_secret\": \"${AUTH0_CLIENT_SECRET}\", "

declare audience=''
[[ -n "${AUTH0_AUDIENCE}" ]] && audience="\"audience\": \"${AUTH0_AUDIENCE}\","

[[ ${AUTH0_DOMAIN} =~ ^http ]] || AUTH0_DOMAIN=https://${AUTH0_DOMAIN}

#            "subject_token_type" : "urn:ietf:params:oauth:token-type:${subject_token_type}",
#            "subject_token_type" : "http://auth0.com/oauth/token-type/third-party-artifact",

declare BODY=$(cat <<EOL
{
            "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
            "subject_token" : "${subject_token}",
            "subject_token_type" : "${subject_token_type}",
            ${audience}
            "scope": "${AUTH0_SCOPE}",
            ${secret}
            "client_id": "${AUTH0_CLIENT_ID}"
}
EOL
)

curl -k -H 'content-type: application/json' \
    -d "${BODY}" \
    --url "${AUTH0_DOMAIN}/oauth/token"

echo