#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-10-25
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v openssl >/dev/null || { echo >&2 "error: openssl not found";  exit 3; }
command -v xxd >/dev/null || { echo >&2 "error: xxd not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-n domain]
        -f cert     # certificate file to generate CNF S256 value to match for token binding
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f mycert.pem
END
    exit $1
}

declare cert_file=''

while getopts "f:hv?" opt; do
    case ${opt} in
    f) cert_file=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${cert_file}" ]] && { echo >&2 "ERROR: cert_file undefined."; usage 1; }
[[ ! -f "${cert_file}" ]] && { echo >&2 "ERROR: cert_file not found: ${cert_file}"; usage 1; }

openssl x509 -in "${cert_file}" -outform DER | openssl dgst -sha256 | cut -d" " -f2 | xxd -r -p - | openssl enc -a | tr -d '='