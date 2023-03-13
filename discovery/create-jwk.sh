#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v openssl &>/dev/null || { echo >&2 "ERROR: openssl not found"; exit 3; }
command -v basenc &>/dev/null || { echo >&2 "ERROR: coreutils(basenc) not found"; exit 3; }

declare pem_file=''
declare kty='RSA'
declare algorithm='RS256'
declare use='sig'

function usage() {
    cat <<END >&2
USAGE: $0 [-e file] [i kid] [-k kty] [-a alg] [-u use] [-f file]
        -e file        # .env file location (default cwd)
        -k kty         # defaults to RSA
        -a algorithm   # algorithm (defaults to RS256)
        -u use         # use tag (default to sig)
        -i kid         # (optional) kid (exporting all KIDs if absent)
        -f file        # public key PEM file
        -h|?           # usage
        -v             # verbose

eg,
     $0 -f ../ca/mydomain.local.key
END
    exit $1
}


while getopts "e:k:a:i:f:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    k) kty=${OPTARG} ;;
    a) algorithm=${OPTARG} ;;
    i) kid=${OPTARG} ;;
    f) pem_file=${OPTARG} ;;
    v) set -x ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -f "${pem_file}" ]] || { echo >&2 "ERROR: pem_file missing: ${pem_file}"; usage 1; }

readonly PUBKEY=$(grep -v -- ----- "${pem_file}" | tr -d '\n')

readonly modulus=$(echo "${PUBKEY}" | base64 -d | openssl asn1parse -inform DER -i -strparse 19 | tail -2 | head -1 | awk '{print $NF}' | tr -d ':' | xxd -r -p | basenc --base64url -w0 | sed -E s/=+$//)
readonly exponent=$(echo "${PUBKEY}" | base64 -d | openssl asn1parse -inform DER -i -strparse 19 | tail -1 | awk '{print $NF}' | tr -d ':' | xxd -r -p | openssl base64 -e -A | tr '+' '-' | tr '/' '_'  | sed -E s/=+$//)

cat <<EOF
{
  "alg": "${algorithm}",
  "kty": "${kty}",
  "use": "${use}",
  "n"  : "${modulus}",
  "e"  : "${exponent}"
}
EOF
