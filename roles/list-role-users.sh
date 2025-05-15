#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2025-05-13
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i role_id] [-o output_file] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i role_id  # role id (required)
        -o file     # output file (default: stdout)
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i rol_123456789
END
  exit $1
}

declare role_id=''
declare output_file=''
declare -i opt_verbose=0

while getopts "e:a:i:o:hv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  a) access_token=${OPTARG} ;;
  i) role_id=${OPTARG} ;;
  o) output_file=${OPTARG} ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${role_id}" ]] && { echo >&2 "ERROR: role_id undefined. Use -i to specify role_id"; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:users"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

# Initialize variables for pagination
declare -i page=0
declare -i per_page=100
declare -i total_users=0
declare all_users="[]"

# Fetch users with pagination
while true; do
  if [[ ${opt_verbose} -eq 1 ]]; then
    echo "Fetching page ${page}..." >&2
  fi

  # Make API request
  response=$(curl -v -s --get -H "Authorization: Bearer ${access_token}" \
    -H 'content-type: application/json' \
    --data-urlencode "page=${page}" \
    --data-urlencode "per_page=${per_page}" \
    --data-urlencode "include_totals=true" \
    --url "${AUTH0_DOMAIN_URL}api/v2/roles/${role_id}/users")

  # Extract users and total count
  users=$(echo "${response}" | jq -r '.users')
  length=$(echo "${response}" | jq -r '.limit')
  total=$(echo "${response}" | jq -r '.total')

  # Display progress
  if [[ ${page} -eq 0 && ${opt_verbose} -eq 1 ]]; then
    echo "Total users: ${total}" >&2
  fi

  # Combine with previous results
  all_users=$(echo "${all_users}" | jq --argjson new "${users}" '. + $new')
  
  # Update total count
  total_users=$((total_users + length))
  
  # Check if we've reached the end
  if [[ ${length} -lt ${per_page} ]]; then
    break
  fi
  
  # Move to next page
  page=$((page + 1))
done

if [[ ${opt_verbose} -eq 1 ]]; then
  echo "Retrieved ${total_users} users" >&2
fi

# Output results
if [[ -n "${output_file}" ]]; then
  echo "${all_users}" | jq '.' > "${output_file}"
  echo "Results saved to ${output_file}" >&2
else
  echo "${all_users}" | jq '.'
fi