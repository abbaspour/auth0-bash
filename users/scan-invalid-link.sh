#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# This script scans search results to find if there are any linked account with unmatched emails
# Date: 2023-11-16
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail


function usage() {
   cat <<END >&2
USAGE: $0 [-f users.json] [-v|-h]
       -f users.json  # user_id
       -o output.json # output file. default to stdout
       -h|?           # usage
       -v             # verbose

eg,
    $0 -f all-users.json -o suspicious.json
END
   exit $1
}

declare file=''
declare output='/dev/stdout'

while getopts "f:o:lshv?" opt; do
    case ${opt} in
    f) file="${OPTARG}" ;;
    o) output="${OPTARG}" ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${file}" ]] && { echo >&2 "ERROR: no input file defined"; usage 1; }
[[ ! -f "${file}" ]] && { echo >&2 "ERROR: no input not found: ${file}"; usage 1; }

jq '.[] | select(.identities | length > 1) | select (.email != .identities[1].profileData.email)' "${file}" | jq -s '.' >> "${output}"