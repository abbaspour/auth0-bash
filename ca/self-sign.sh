#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -euo pipefail

which curl >/dev/null || {
    echo >&2 "error: curl not found"
    exit 3
}
which jq >/dev/null || {
    echo >&2 "error: jq not found"
    exit 3
}
function usage() {
    cat <<END >&2
USAGE: $0 [-n domain]
        -n name     # name of key pair
        -h|?        # usage
        -v          # verbose

eg,
     $0 -n backend-api
END
    exit $1
}

declare pair_name=''
declare opt_verbose=0

while getopts "n:hv?" opt; do
    case ${opt} in
    n) pair_name=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${pair_name}" ]] && {
    echo >&2 "ERROR: pair_name undefined."
    usage 1
}

declare -r private_key="${pair_name}-private.pem"
declare -r cert_key="${pair_name}-cert.pem"
declare -r public_key="${pair_name}-public.pem"

cat >openssl.cnf <<-EOF
  [req]
  distinguished_name = req_distinguished_name
  x509_extensions = v3_req
  prompt = no
  [req_distinguished_name]
  CN = ${pair_name}
  [v3_req]
  keyUsage = keyEncipherment, dataEncipherment
  extendedKeyUsage = serverAuth
EOF

openssl req -nodes -new -x509 -config openssl.cnf -keyout ${private_key} -out ${cert_key}
openssl x509 -inform PEM -in ${cert_key} -pubkey -noout >${public_key}

rm openssl.cnf
