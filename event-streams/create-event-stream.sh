#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2025-01-28
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-n name] [-s type(s)] [-d type] [-u endpoint] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -n name         # event stream name (e.g. "my-event-stream")
        -t type(s)      # subscription event types ("user.created", "user.updated", "user.deleted") comma seperated.
        -d type         # destination type ("webhook", "eventbridge")
        -u endpoint     # webhook endpoint
        -r region       # AWS region
        -i account      # AWS account number id
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n "my-event-stream-1" -s user.created,user.updated,user.deleted -d webhook -u https://example.com/webhook
END
  exit $1
}

declare stream_name=''
declare subscription_types=''
declare destination_type=''
declare webhook_endpoint=''
declare aws_region=''
declare aws_account_id=''

while getopts "e:a:n:s:d:u:r:i:hv?" opt; do
  case ${opt} in
  e) source ${OPTARG} ;;
  a) access_token=${OPTARG} ;;
  n) stream_name=${OPTARG} ;;
  s) subscription_types=${OPTARG} ;;
  d) destination_type=${OPTARG} ;;
  u) webhook_endpoint=${OPTARG} ;;
  r) aws_region=${OPTARG} ;;
  i) aws_account_id=${OPTARG} ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:event_streams"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${stream_name}" ]] && { echo >&2 "ERROR: stream_name undefined."; usage 1; }
[[ -z "${subscription_types}" ]] && { echo >&2 "ERROR: subscription_types undefined."; usage 1; }
[[ -z "${destination_type}" ]] && { echo >&2 "ERROR: destination_type undefined."; usage 1; }

# Convert the input into an array
IFS=',' read -r -a items <<< "${subscription_types}"

declare subscriptions_field='"subscriptions":['

# Loop through the items and format them into JSON objects
for i in "${!items[@]}"; do
  # Append the JSON object for each item
  subscriptions_field+='{"event_type": "'"${items[i]}"'"}'

  # Add a comma after each object except the last one
  if [ "$i" -lt $((${#items[@]} - 1)) ]; then
    subscriptions_field+=','
  fi
done

declare configuration_field=''

if [[ "${destination_type}" == "webhook" ]]; then
  [[ -z "${webhook_endpoint}" ]] && { echo >&2 "ERROR: webhook_endpoint undefined."; usage 1; }
  configuration_field=$(cat <<EOL
      "webhook_endpoint": "${webhook_endpoint}",
      "webhook_authorization": {
        "method": "bearer",
        "token": "my-token"
      }
EOL
  )
elif [[ "${destination_type}" == "eventbridge" ]]; then
  [[ -z "${aws_region}" ]] && { echo >&2 "ERROR: aws_region undefined."; usage 1; }
  [[ -z "${aws_account_id}" ]] && { echo >&2 "ERROR: aws_account_id undefined."; usage 1; }

  configuration_field=$(cat <<EOL
      "aws_region": "${aws_region}",
      "aws_account_id": "${aws_account_id}"
EOL
  )

else
  echo >&2 "ERROR: unsupported destination_type: ${destination_type}"; usage 1;
fi

# End the JSON string
subscriptions_field+=']'

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

declare BODY=$(cat <<EOL
{
  "name": "${stream_name}",
  ${subscriptions_field},
  "destination": {
    "type": "${destination_type}",
    "configuration": {
      ${configuration_field}
    }
  }
}
EOL
)

curl -s -k --request POST \
  -H "Authorization: Bearer ${access_token}" \
  --data "${BODY}" \
  --header 'content-type: application/json' \
  --url "${AUTH0_DOMAIN_URL}api/v2/event-streams" | jq .
