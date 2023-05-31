#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-05-31
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -euo pipefail

command -v oathtool >/dev/null || { echo >&2 "error: oathtool not found";  exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare secret=''

function usage() {
    cat <<END >&2
USAGE: $0 [-s secret] [-v|-h]
        -s secret   # base32 secret
        -S secret   # plain secret
        -h|?        # usage
        -v          # verbose

eg,
     $0 -S hellohellohello
END
    exit $1
}

while getopts "e:s:S:hv?" opt; do
    case ${opt} in
    s) secret=${OPTARG} ;;
    S) secret=$(echo -n "${OPTARG}" | base32 -w0) ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${secret}" ]] && { echo >&2 "ERROR: secret undefined."; usage 1; }

oathtool --base32 --totp "${secret}" -d 6