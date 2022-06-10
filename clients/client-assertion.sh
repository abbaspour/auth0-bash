#!/usr/bin/env bash

set -eo pipefail

which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }
which jq > /dev/null || { echo >&2 "error: jq not found"; exit 3; }


function usage() {
    cat <<END >&2
USAGE: $0 [-t tenant] [-d domain] [-i client_id] [-f file] [-k kid] [-v|-h]
        -e file         # .env file location (default cwd)
        -t tenant       # Auth0 tenant@region
        -d domain       # Auth0 domain
        -i client_id    # client_id
        -k kid          # client key id
        -f file         # private key PEM  file
        -h|?            # usage
        -v              # verbose

eg,
     $0 -d abbaspour.auth0.com -i 6KS0YSEQwsvE9qRqtzonX8SEgJEYVzVH -k mykid -f ../ca/mydomain.local.key
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare client_id=''
declare pem_file=''
declare kid=''

while getopts "e:t:d:i:f:k:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.');;
        d) AUTH0_DOMAIN="${OPTARG}";;
        i) client_id=${OPTARG};;
        f) pem_file=${OPTARG};;
        k) kid=${OPTARG};;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined."; usage 1; }
[[ -z "${kid}" ]] && { echo >&2 "ERROR: kid undefined."; usage 1; }
[[ -z "${pem_file}" ]] && { echo >&2 "ERROR: pem_file undefined."; usage 1; }
[[ -f "${pem_file}" ]] || { echo >&2 "ERROR: pem_file missing: ${pem_file}"; usage 1; }

readonly exp=$(date +%s --date='5 minutes')
readonly now=$(date +%s)

readonly header=$(printf '{"typ":"JWT","alg":"RS256","kid":"%s"}' "${kid}" | openssl base64 -e -A | sed s/\+/-/ | sed -E s/=+$//)
readonly body=$(printf '{"iat": %s, "iss":"%s","sub":"%s","aud":"https://%s/","exp":%s, "jti": "%s"}' "${now}" "${client_id}" "${client_id}" "${AUTH0_DOMAIN}" "${exp}" "${now}" | openssl base64 -e -A | sed s/\+/-/ | sed -E s/=+$//)
readonly signature=$(echo -n "${header}.${body}" | openssl dgst -sha256 -sign "${pem_file}" -binary | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//)

# jwt
echo "${header}.${body}.${signature}"

