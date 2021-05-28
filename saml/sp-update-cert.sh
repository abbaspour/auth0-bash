#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-c cert-file] [-p key-file] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # client_id
        -c cert.pem # certficate PEM file
        -k ley.pem  # private key PEM file
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit $1
}

declare cert_file=''
declare key_file=''
declare client_id=''

while getopts "e:a:i:c:k:dhv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        i) client_id=${OPTARG};;
        c) cert_file=${OPTARG};;
        k) key_file=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined."; usage 1; }
[[ -z "${cert_file}" ]] && { echo >&2 "ERROR: cert_file undefined."; usage 1; }
[[ -z "${key_file}" ]] && { echo >&2 "ERROR: key_file undefined."; usage 1; }
[[ -f "${cert_file}" ]] || { echo >&2 "ERROR: cert_file missing: ${cert_file}"; usage 1; }
[[ -f "${key_file}" ]] || { echo >&2 "ERROR: key_file missing: ${key_file}"; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare -r cert_txt=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ${cert_file})
declare -r key_txt=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ${key_file})

declare BODY=$(cat <<EOL
{
  "options": {
    "signing_keys": {
      "cert": "${cert_txt}",
      "key": "${key_txt}"
    }
  }
}
EOL
)

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/clients/${client_id} \
    --header 'content-type: application/json' \
    --data "${BODY}"
