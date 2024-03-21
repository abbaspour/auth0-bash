#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-i id_token] [-b browser] [-f|-C|-o|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -f             # federated logout
        -i id_token    # id_token_hint (for RP initiated logout)
        -s hint        # sid or user_id logout hint (for RP initiated logout)
        -C             # copy to clipboard
        -o             # Open URL
        -b browser     # Choose browser to open (firefox, chrome, safari)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -f -o -b firefox
END
    exit $1
}

declare opt_federated=0
declare opt_rp_initiated=0
declare id_token_hint=''
declare logout_hint=''

while getopts "e:t:d:c:u:b:i:s:fCohv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    u) AUTH0_REDIRECT_URI=${OPTARG} ;;
    i) id_token_hint=${OPTARG}; opt_rp_initiated=1 ;;
    s) logout_hint=${OPTARG}; opt_rp_initiated=1 ;;
    C) opt_clipboard=1 ;;
    o) opt_open=1 ;;
    f) opt_federated=1 ;;
    b) opt_browser="-a ${OPTARG} " ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z ${AUTH0_DOMAIN+x} ]] && {
  if [[ -n "${id_token_hint}" ]]; then
      AUTH0_DOMAIN=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${id_token_hint}")
  else
    echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;
  fi
}

[[ ${AUTH0_DOMAIN} =~ ^http ]] || AUTH0_DOMAIN=https://${AUTH0_DOMAIN}
[[ ${AUTH0_DOMAIN} =~ \/$ ]] || AUTH0_DOMAIN+='/'

declare logout_url

if [[ -n "${opt_rp_initiated}" ]]; then
  logout_url="${AUTH0_DOMAIN}oidc/logout?"

  [[ -n "${id_token_hint}" ]] && logout_url+="id_token_hint=${id_token_hint}&"
  [[ -n "${logout_hint}" ]] && {
    [[ -n "${AUTH0_CLIENT_ID}" ]] || { echo >&2 "ERROR: client_id required for logout with logout_hint";  usage 1;  }
    logout_url+="client_id=${AUTH0_CLIENT_ID}&logout_hint=${logout_hint}&"
  }
else
  logout_url="${AUTH0_DOMAIN}v2/logout?"

  [[ ${opt_federated} -ne 0 ]] && logout_url+="federated&"
  [[ -n "${AUTH0_CLIENT_ID}" ]] && logout_url+="client_id=${AUTH0_CLIENT_ID}&"
  [[ -n "${AUTH0_REDIRECT_URI}" ]] && logout_url+="returnTo=$(urlencode ${AUTH0_REDIRECT_URI})&"
fi


echo "${logout_url}"

[[ -n "${opt_clipboard}" ]] && echo "${logout_url}" | pbcopy
[[ -n "${opt_open}" ]] && open ${opt_browser} "${logout_url}"
