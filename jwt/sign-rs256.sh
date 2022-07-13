#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
declare alg='RS256'

function usage() {
    cat <<END >&2
USAGE: $0 [-f json] [-i iss] [-a aud] [-k kid] [-p private-key] [-v|-h]
        -f file        # JSON file to sign
        -i iss         # Issuer
        -a aud         # audience
        -k kid         # Key ID
        -A alg         # algorithm. default ${alg}
        -h|?           # usage
        -v             # verbose

eg,
     $0 -f file.json -a http://my.api -i http://some.issuer -k 1 -p ../ca/myapi-private.pem
END
    exit $1
}

declare opt_verbose=0
declare aud=''
declare iss=''
declare kid=''
declare json_file=''
declare pem_file=''

while getopts "f:i:a:k:p:A:hv?" opt; do
    case ${opt} in
    f) json_file=${OPTARG} ;;
    i) iss=${OPTARG} ;;
    a) aud=${OPTARG} ;;
    k) kid=${OPTARG} ;;
    p) pem_file=${OPTARG} ;;
    A) alg=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

#[[ -z "${aud}" ]] && { echo >&2 "ERROR: audience undefined."; usage 1; }
#[[ -z "${iss}" ]] && { echo >&2 "ERROR: iss undefined."; usage 1; }
[[ -z "${kid}" ]] && { echo >&2 "ERROR: kid undefined.";  usage 1; }

#[[ -z "${pem_file}" ]] && { echo >&2 "ERROR: pem_file undefined."; usage 1; }
#[[ -f "${pem_file}" ]] || { echo >&2 "ERROR: pem_file missing: ${pem_file}"; usage 1; }
[[ -z "${json_file}" ]] && { echo >&2 "ERROR: json_file undefined";  usage 1; }

[[ ! -f "${json_file}" ]] && { echo >&2 "json_file: unable to read file: ${json_file}";  usage 1; }


# header
declare -r header=$(printf '{"typ":"JWT","alg":"%s","jti":"%s"}' "${alg}" "${kid}" | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//)

# body
declare -r body=$(cat "${json_file}" | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//)

#echo "${header}.${body}"
declare alg_lower=$(echo -n "$alg" | tr '[:upper:]' '[:lower:]')

declare signature=''
if [[ ${alg_lower} != 'none' ]]; then
    signature=$(echo -n "${header}.${body}" | openssl dgst -sha256 -sign "${pem_file}" -binary | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//)
    signature=".${signature}"
fi

# jwt
echo "${header}.${body}${signature}"
