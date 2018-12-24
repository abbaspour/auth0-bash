#!/usr/bin/env bash

set -eo pipefail

which awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }
which base64 > /dev/null || { echo >&2 "error: base64 not found"; exit 3; }
which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-t tenant] [-d domain] [-a audience] [-f file] [-k kid] [-v|-h]
        -e file         # .env file location (default cwd)
        -t tenant       # Auth0 tenant@region
        -d domain       # Auth0 domain
        -a audience     # audience
        -k kid          # key id (should match kid of RS/verificationKeys)
        -f file         # PEM private key file
        -h|?            # usage
        -v              # verbose

eg,
     $0 -a my.api -k mykid -f ../ca/mydomain.local.key
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare aud=''
declare pem_file=''
declare kid=''

while getopts "e:t:d:a:f:k:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        a) aud=${OPTARG};;
        i) rs_id=${OPTARG};;
        f) pem_file=${OPTARG};;
        k) kid=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${aud}" ]] && { echo >&2 "ERROR: audience undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${kid}" ]] && { echo >&2 "ERROR: kid undefined."; usage 1; }
[[ -z "${pem_file}" ]] && { echo >&2 "ERROR: pem_file undefined."; usage 1; }
[[ -f "${pem_file}" ]] || { echo >&2 "ERROR: pem_file missing: ${pem_file}"; usage 1; }

# header
declare -r header=`printf '{"typ":"JWT","alg":"RS256","kid":"%s"}' "${kid}" | openssl base64 -e -A | sed s/\+/-/ | sed -E s/=+$//`
#echo "header: ${header}"

# body
declare -r body=`printf '{"iss":"%s","sub":"%s","aud":"https://%s/","exp":1798754127}' "${aud}" "${aud}" "${AUTH0_DOMAIN}" | openssl base64 -e -A | sed s/\+/-/ | sed -E s/=+$//`
#echo "body: ${body}"

#echo "${header}.${body}"

declare -r signature=`echo -n "${header}.${body}" | openssl dgst -sha256 -sign "${pem_file}" -binary | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//`
#echo "signature: ${signature}"

# jwt
echo "${header}.${body}.${signature}"

