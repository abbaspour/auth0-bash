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
declare -i total_users=0
declare all_users="[]"
declare next_param=""

# Fetch users with checkpoint pagination
while true; do
  if [[ ${opt_verbose} -eq 1 ]]; then
    if [[ -z "${next_param}" ]]; then
      echo "Fetching first batch of users..." >&2
    else
      echo "Fetching next batch of users..." >&2
    fi
  fi

  # Make API request
  if [[ -z "${next_param}" ]]; then
    # First request - use take=100
    response=$(curl -s --get -H "Authorization: Bearer ${access_token}" \
      -H 'content-type: application/json' \
      --data-urlencode "take=100" \
      --url "${AUTH0_DOMAIN_URL}api/v2/roles/${role_id}/users")
  else
    # Subsequent requests - use the next parameter
    response=$(curl -s --get -H "Authorization: Bearer ${access_token}" \
      -H 'content-type: application/json' \
      --data-urlencode "take=100" \
      --data-urlencode "from=${next_param}" \
      --url "${AUTH0_DOMAIN_URL}api/v2/roles/${role_id}/users")
  fi

  # Extract users and next parameter
  users=$(echo "${response}" | jq -r '. | if has("users") then .users else . end')
  next_param=$(echo "${response}" | jq -r '.next // empty')
  length=$(echo "${users}" | jq -r 'length // 0')

  # Combine with previous results
  all_users=$(echo "${all_users}" | jq --argjson new "${users}" '. + $new')

  # Update total count
  total_users=$((total_users + length))

  # Display progress
  if [[ ${opt_verbose} -eq 1 ]]; then
    echo "Retrieved ${length} users in this batch (total so far: ${total_users})" >&2
  fi

  # Check if we've reached the end (no next parameter)
  if [[ -z "${next_param}" ]]; then
    break
  fi
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
