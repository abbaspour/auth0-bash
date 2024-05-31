#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-05-27
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

##
# prerequisite:
# 1. create a clients with type SPA
# 2. add allowed callback to clients: https://jwt.io
# 3. ./saml-authnreq.sh -t tenant -c client_id
##

declare binding='redirect'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-D destination] [-c client_id] [-r connection] [-b binding] [-u acs] [-I issuer] [-C|-N|-o|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain (IdP)
        -c client_id   # Auth0 client ID (IdP)
        -r realm       # Connection
        -u acs         # ACS callback URL (default is issuer/login/callback)
        -S state       # relay state
        -H hint        # login hint
        -O org_id      # organisation id
        -i tenant      # issuer Auth0 tenant (SP)
        -R realm       # issuer Auth0 connection realm (SP)
        -I issuer      # generic issuer (SP)
        -l locale      # ui_locales
        -k key_id      # client credentials key_id
        -K file.pem    # client credentials private key
        -p             # SAML POST binding; default is redirect
        -C             # copy to clipboard
        -N             # no pretty print
        -o             # Open URL
        -B browser     # Choose browser to open (firefox, chrome, safari)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -s offline_access -o
END
    exit $1
}

urlencode() {
    jq -rn --arg x "${1}" '$x|@uri'
}

random32() {
    for i in {0..32}; do echo -n $((RANDOM % 10)); done
}

base64URLEncode() {
  echo -n "$1" | base64 -w0 | tr '+' '-' | tr '/' '_' | tr -d '='
}

base64Encode() {
  echo -n "$1" | base64 -w0
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CONNECTION=''

declare opt_open=''
declare opt_clipboard=''
declare opt_state=''
declare opt_login_hint=''
declare org_id=''
declare issuer_tenant=''
declare issuer_realm=''
declare Issuer=''
declare Destination=''
declare AssertionConsumerServiceURL=''
declare ui_locales=''
declare key_id=''
declare key_file=''
declare opt_browser=''
declare opt_pp=1

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:t:d:D:c:r:u:B:M:S:n:H:O:i:R:I:l:E:k:K:D:pCoNhv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    D) Destination=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    r) AUTH0_CONNECTION=${OPTARG} ;;
    u) AssertionConsumerServiceURL="AssertionConsumerServiceURL=\"${OPTARG}\"" ;;
    S) opt_state=${OPTARG} ;;
    H) opt_login_hint=${OPTARG} ;;
    O) org_id=${OPTARG} ;;
    i) issuer_tenant=$(echo "${OPTARG}" | tr '@' '.') ;;
    R) issuer_realm=${OPTARG} ;;
    I) Issuer=${OPTARG} ;;
    l) ui_locales=${OPTARG} ;;
    k) key_id="${OPTARG}";;
    K) key_file="${OPTARG}";;
    p) binding='POST' ;;
    C) opt_clipboard=1 ;;
    N) opt_pp=0 ;;
    o) opt_open=1 ;;
    B) opt_browser="-a ${OPTARG^}" ;;
    v) set -x ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done


[[ -z "${Issuer}" ]] && {
  [[ -z "${issuer_tenant}" ]] && {  echo >&2 "ERROR: issuer_tenant undefined";  usage 1;  }
  [[ -z "${issuer_realm}" ]] && { echo >&2 "ERROR: issuer_realm undefined";  usage 1; }
  Issuer="urn:auth0:${issuer_tenant%.*}:${issuer_realm}";
}

[[ -z "${Destination}" ]] && {
  [[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
  [[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined";  usage 1; }
  [[ ${AUTH0_DOMAIN} =~ ^http ]] || AUTH0_DOMAIN=https://${AUTH0_DOMAIN}
  Destination="${AUTH0_DOMAIN}/samlp/${AUTH0_CLIENT_ID}"
  [[ -n "${AUTH0_CONNECTION}" ]] && Destination+="?connection=${AUTH0_CONNECTION}"
}


declare -r IssueInstant=$(date +"%Y-%m-%dT%H:%M:%SZ")

#    <saml:Subject>
#        @@LoginHint@@
#    </saml:Subject>

declare -r AuthnRequestPayload=$(cat <<EOL
<samlp:AuthnRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
  ${AssertionConsumerServiceURL} Destination="${Destination}"
  ID="ID$(random32)"
  IssueInstant="${IssueInstant}"
  ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-${binding^}" Version="2.0">
    <saml:Issuer xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">
        ${Issuer}
    </saml:Issuer>
</samlp:AuthnRequest>
EOL
)

echo "${AuthnRequestPayload}"


echo "${AuthnRequest}"

declare authorize_url=''
declare SAMLRequest=''

if [[ "${binding}" == 'redirect' ]]; then
  SAMLRequest=$(base64URLEncode "${AuthnRequestPayload}")
  authorize_url="${Destination}?SAMLRequest=${SAMLRequest}"
else
  SAMLRequest=$(base64Encode "${AuthnRequestPayload}")

  html=$(mktemp --suffix=.html)
  cat <<EOL >"${html}"
<html>
<head>
    <title>SAML POST Working...</title>
</head>
<body>
    <form method="post" name="hiddenform" action="${Destination}">
        <input type="hidden"
               name="SAMLRequest"
               value="${SAMLRequest}">
        <input type="hidden" name="RelayState" value="${state}">
        <noscript>
            <p>
                Script is disabled. Click Submit to continue.
            </p><input type="submit" value="Submit">
        </noscript>
    </form>
    <script language="javascript" type="text/javascript">
        window.setTimeout('document.forms[0].submit()', 0);
    </script>
</body>
</html>
EOL
  authorize_url="file://${html}"
fi

if [[ ${opt_pp} -eq 0 ]]; then
  echo "${authorize_url}"
else
    echo "${authorize_url}" | sed -E 's/&/ &\
    /g; s/%20/ /g; s/%3A/:/g;s/%2F/\//g'
fi

[[ -n "${opt_clipboard}" ]] && echo "${authorize_url}" | pbcopy
[[ -n "${opt_open}" ]] && open ${opt_browser} "${authorize_url}"
