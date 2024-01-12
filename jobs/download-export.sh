#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-11-16
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
command -v wget >/dev/null || {  echo >&2 "error: wget not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i job_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # job_id
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i job_PwSvrMnLwgxZOWYg
END
    exit $1
}

declare job_id=''

while getopts "e:a:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) job_id=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPES=("read:users" "create:users")
[[ " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[0]} "* || " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[1]} "*  ]] \
    || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected (any of): '${EXPECTED_SCOPES[*]}', Available: '$AVAILABLE_SCOPES'"; exit 1; }
# Note: create:users scope is required for user import/verification email job stats. read:users is required for user export job stats.

[[ -z "${job_id}" ]] && { echo >&2 "ERROR: job_id undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

readonly status=$(curl -s -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/jobs/${job_id}" | jq -r .status)

if [[ "${status}" != "completed" ]]; then
    echo "job is not completed yet. status is: ${status}"
    exit 1
fi

readonly location=$(curl -s -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/jobs/${job_id}" | jq -r .location)

echo "$location"

readonly file_name=$(echo "${location}"  | grep -E -o "([^\/]+\.gz)")

echo "$file_name"

wget -O "${file_name}" "${location}"

