#!/bin/bash

set -euo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-d device_id] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # Access Token
        -d device_id   # device_id
        -h|?           # usage
        -v             # verbose

eg,
     $0 -d dcr_yzt4x4f76kLTXGFW
END
    exit $1
}

declare device_id=''
declare opt_verbose=0

while getopts "e:a:d:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        d) device_id=${OPTARG};;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${device_id}" ]] && { echo >&2 "ERROR: device_id undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

curl -s --request DELETE \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/device-credentials/${device_id}

