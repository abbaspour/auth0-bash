#!/bin/bash

set -eo pipefail

declare iss='http://www.auth0.life/'
declare kid='1'
declare secret='secret'
declare file=''

function usage() {
    cat <<END >&2
USAGE: $0 [-f file] [-s secret] [-i iss] [-k kid] [-e exp]
        -f file        # JSON file to sign
        -s secret      # Shared secret (default ${secret})
        -i iss         # Issuer (default ${iss})
        -k kid         # Key ID (default ${kid})
        -e exp         # Expiry in minutes
        -h|?           # usage
        -v             # verbose

eg,
     $0 -f file.json
END
    exit $1
}

declare opt_verbose=0

while getopts "f:s:i:k:e:hv?" opt
do
    case ${opt} in
        f) file=${OPTARG};;
        s) secret=${OPTARG};;
        i) iss=${OPTARG};;
        k) kid=${OPTARG};;
        e) exp=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${file}" ]] && { echo >&2 "ERROR: file undefined"; usage 1; }
[[ ! -f "${file}" ]] && { echo >&2 "ERROR: unable to read file: ${file}"; usage 1; }

# header
declare -r header=`printf '{"typ": "JWT", "alg": "HS256", "kid": "%s", "iss": "%s"}' "${kid}" "${iss}" | base64 -w0`

# body
declare -r body=`base64 -w0 ${file}`

# signature
declare -r signature=`echo -n "${header}.${body}" | openssl dgst -binary -sha256 -hmac "${secret}" | base64 -w0`

# jwt
echo "${header}.${body}.${signature}"

# TODO: add exp
