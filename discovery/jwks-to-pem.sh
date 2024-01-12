#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

# downloads x5c of jwks.json into a PEM file

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
command -v fold &>/dev/null || { echo >&2 "ERROR: fold not found"; exit 3; }
command -v openssl &>/dev/null || { echo >&2 "ERROR: openssl not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e file] [-t tenant] [-d domain] [-k kid]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -u url         # JWKS url
        -k kid         # (optional) kid (exporting all KIDs if absent)
        -D             # Dump certificate
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare opt_dump=''
declare jwks_url=''
declare KID=''

while getopts "e:t:d:f:u:k:Dhv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    u) jwks_url=${OPTARG} ;;
    f) cert_file=${OPTARG} ;;
    k) KID=${OPTARG} ;;
    D) opt_dump=1 ;;
    v) set -x ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

if [[ -z "${jwks_url}" ]]; then
    [[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
    jwks_url=$(curl -s "https://${AUTH0_DOMAIN}/.well-known/openid-configuration" | jq -r '.jwks_uri')
else
    AUTH0_DOMAIN='generic'
fi

for k in $(curl -s "${jwks_url}" | jq -r '.keys[] .kid'); do
    [[ -n "${KID}" && ! "${k}" =~ ${KID} ]] && continue
    echo "Exporting KID: ${k}"
    declare cert_file="${AUTH0_DOMAIN}-${k}-certificate.pem"
    declare public_key_file="${AUTH0_DOMAIN}-${k}-public_key.pem"

    echo "  cert_file: ${cert_file}"
    echo "  public_key_file: ${public_key_file}"

    declare x5c=$(curl -s "${jwks_url}" | jq -r ".keys [] | select(.kid==\"${k}\") |  .x5c [0]")
    echo '-----BEGIN CERTIFICATE-----' >"${cert_file}"
    echo "$x5c" | fold -w64 >>"${cert_file}"
    echo '-----END CERTIFICATE-----' >>"${cert_file}"

    openssl x509 -in "${cert_file}" -pubkey -noout >"${public_key_file}"

    [[ ${opt_dump} ]] && openssl x509 -in "${cert_file}" -text -noout

done
