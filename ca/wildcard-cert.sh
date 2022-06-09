##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -euo pipefail

which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }
which jq > /dev/null || { echo >&2 "error: jq not found"; exit 3; }
function usage() {
  cat <<END >&2
USAGE: $0 [-d domain]
        -d domain   # domain
        -h|?        # usage
        -v          # verbose

eg,
     $0 -d mydomain.local
END
  exit $1
}

declare DOMAIN=''
declare opt_verbose=0

while getopts "d:hv?" opt; do
  case ${opt} in
  d) DOMAIN=${OPTARG} ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${DOMAIN}" ]] && {
  echo >&2 "ERROR: DOMAIN undefined."
  usage 1
}

declare -r private_key="${DOMAIN}-private.pem"
declare -r public_key="${DOMAIN}-public.pem"

echo " Generating wildcart certificate: *.$DOMAIN"

cat >openssl.cnf <<-EOF
  [req]
  distinguished_name = req_distinguished_name
  x509_extensions = v3_req
  prompt = no
  [req_distinguished_name]
  CN = *.$DOMAIN
  [v3_req]
  keyUsage = keyEncipherment, dataEncipherment
  extendedKeyUsage = serverAuth
EOF

openssl req \
  -new \
  -newkey rsa:2048 \
  -sha1 \
  -days 3650 \
  -nodes \
  -x509 \
  -keyout $DOMAIN.pkcs8.key \
  -out $DOMAIN.crt \
  -config openssl.cnf

openssl rsa -in $DOMAIN.pkcs8.key -out $DOMAIN.key

rm openssl.cnf $DOMAIN.pkcs8.key
