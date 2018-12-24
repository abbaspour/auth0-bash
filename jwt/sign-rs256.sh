#!/bin/bash

set -eo pipefail


function usage() {
    cat <<END >&2
USAGE: $0 [-f json] [-i iss] [-a aud] [-k kid] [-p private-key] [-v|-h]
        -f file        # JSON file to sign
        -i iss         # Issuer
        -a aud         # audience
        -k kid         # Key ID
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

while getopts "f:i:a:k:p:hv?" opt
do
    case ${opt} in
        f) json_file=${OPTARG};;
        i) iss=${OPTARG};;
        a) aud=${OPTARG};;
        k) kid=${OPTARG};;
        p) pem_file=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done


[[ -z "${aud}" ]] && { echo >&2 "ERROR: audience undefined."; usage 1; }
[[ -z "${iss}" ]] && { echo >&2 "ERROR: iss undefined."; usage 1; }
[[ -z "${kid}" ]] && { echo >&2 "ERROR: kid undefined."; usage 1; }
[[ -z "${pem_file}" ]] && { echo >&2 "ERROR: pem_file undefined."; usage 1; }
[[ -f "${pem_file}" ]] || { echo >&2 "ERROR: pem_file missing: ${pem_file}"; usage 1; }
[[ -z "${json_file}" ]] && { echo >&2 "ERROR: json_file undefined"; usage 1; }
[[ ! -f "${json_file}" ]] && { echo >&2 "json_file: unable to read file: ${json_file}"; usage 1; }

# header
declare -r header=`printf '{"typ":"JWT","alg":"RS256","kid":"%s"}' "${kid}" | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//`

# body
declare -r body=`cat ${json_file} | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//`

#echo "${header}.${body}"

declare -r signature=`echo -n "${header}.${body}" | openssl dgst -sha256 -sign "${pem_file}" -binary | openssl base64 -e -A | tr '+' '-' | tr '/' '_' | sed -E s/=+$//`

# jwt
echo "${header}.${body}.${signature}"
