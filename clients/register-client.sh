#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


# make sure
# 1. "OIDC Dynamic Application Registration" is enabled for your tenant. Visit Manage > Tenant Settings > Advanced
# 2. desired connection is domain level. PATCH connection to set `is_domain_connection` to true or use update-connection.sh

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-n name] [-r uri,uri] [-p|-v|-h]
        -e file         # .env file location (default cwd)
        -t tenant       # Auth0 tenant@region
        -d domain       # Auth0 domain
        -n name         # client name (e.g. "My Client")
        -r redirect_uri # comma seperated redirect_uris
        -p              # public client. set token_endpoint_auth_method to none. default is client_secret_post
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n "My App" -r https://jwt.io -p
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare client_name=''
declare token_endpoint_auth_method='client_secret_post'
declare input_redirect_uris=''

while getopts "e:t:d:n:r:phv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    n) client_name=${OPTARG} ;;
    r) input_redirect_uris=${OPTARG} ;;
    p) token_endpoint_auth_method='none' ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined.";  usage 1; }

[[ -z "${client_name}" ]] && { echo >&2 "ERROR: client_name undefined.";  usage 1; }


declare -r redirect_uris=$(echo ${input_redirect_uris} | sed 's/,/","/g')

declare BODY=$( cat <<EOL
{
  "client_name": "${client_name}",
  "redirect_uris": ["${redirect_uris}"],
  "token_endpoint_auth_method": "${token_endpoint_auth_method}"
}
EOL
)

curl --request POST \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url https://${AUTH0_DOMAIN}/oidc/register
