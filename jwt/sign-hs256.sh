#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eu #o pipefail

declare secret=''
declare algorithm='HS256'
declare file=''

function usage() {
    cat <<END >&2
USAGE: $0 [-f file] [-s secret] [-k kid] [-e exp]
        -f file        # JSON file to sign
        -a algorithm   # algorithm; none or hs256 (default)
        -s secret      # Shared secret (default ${secret})
        -h|?           # usage
        -v             # verbose

eg,
     $0 -f file.json -s hardsecret
END
    exit $1
}

declare opt_verbose=0

while getopts "f:s:a:hv?" opt; do
    case ${opt} in
    f) file=${OPTARG} ;;
    a) algorithm=${OPTARG} ;;
    s) secret=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${file}" ]] && {
    echo >&2 "ERROR: file undefined"
    usage 1
}
[[ ! -f "${file}" ]] && {
    echo >&2 "ERROR: unable to read file: ${file}"
    usage 1
}

# header
declare -r header=$(printf '{"alg": "%s", "typ": "JWT"}' "${algorithm}" | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//)

# body
declare -r body=$(cat "${file}" | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//)

# signature
declare signature=''
if [[ "${algorithm}" != "none" ]]; then
    [[ -z "${secret}" ]] && {
        echo >&2 "ERROR: secret undefined"
        usage 1
    }
    signature=$(echo -n "${header}.${body}" | openssl dgst -binary -sha256 -hmac "${secret}" | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//)
    signature=".${signature}"
fi

# jwt
echo "${header}.${body}${signature}"
