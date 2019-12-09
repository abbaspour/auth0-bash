#!/bin/bash

set -eu #o pipefail

declare iss='http://www.auth0.life/'
declare kid='1'
declare secret=''
declare file=''

function usage() {
    cat <<END >&2
USAGE: $0 [-f file] [-s secret] [-k kid] [-e exp]
        -f file        # JSON file to sign
        -s secret      # Shared secret (default ${secret})
        -k kid         # Key ID (default ${kid})
        -h|?           # usage
        -v             # verbose

eg,
     $0 -f file.json -s hardsecret
END
    exit $1
}

declare opt_verbose=0

while getopts "f:s:k:hv?" opt
do
    case ${opt} in
        f) file=${OPTARG};;
        s) secret=${OPTARG};;
        k) kid=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${file}" ]] && { echo >&2 "ERROR: file undefined"; usage 1; }
[[ ! -f "${file}" ]] && { echo >&2 "ERROR: unable to read file: ${file}"; usage 1; }
[[ -z "${secret}" ]] && { echo >&2 "ERROR: secret undefined"; usage 1; }

# header
declare -r header=`printf '{"typ": "JWT", "alg": "HS256", "kid": "%s"}' "${kid}" | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//`

# body
declare -r body=`cat ${file} | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//`

# signature
declare -r signature=`echo -n "${header}.${body}" | openssl dgst -binary -sha256 -hmac "${secret}" | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//`

# jwt
echo "${header}.${body}.${signature}"
