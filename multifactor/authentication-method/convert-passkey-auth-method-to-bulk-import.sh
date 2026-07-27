#!/bin/bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-07-06
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -euo pipefail

command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

# Initialize variables
declare USER_ID=""
declare EMAIL=""

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-i user_id] [-m email] [-v|-h]
        -i user_id  # user_id, e.g. 'auth0|5b5fb9702e0e740478884234'
        -m email    # email
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|6a4aef4dae14f3382b2d4d70' -m 'u1@j6.com'
END
    exit $1
}


# Parse command line arguments
while getopts "i:m:" opt; do
  case $opt in
    i) USER_ID="$OPTARG" ;;
    m) EMAIL="$OPTARG" ;;
    h | ?) usage 0 ;;
    *) usage 1;;
  esac
done

# Validate required arguments
if [[ -z "$USER_ID" || -z "$EMAIL" ]]; then
  echo "Error: Both -i <user_id> and -m <email> are required." >&2
  usage 1;
fi

# Call the external script, ensure it succeeds, and pipe the output to jq
"${DIR}/list-authentication-methods.sh" -i "$USER_ID" | jq --arg email "$EMAIL" '
  # 1. Filter only items where type is "passkey"
  map(select(.type == "passkey")) |

  # 2. Group by user_handle (in case a user has multiple, though typically they have one)
  group_by(.user_handle) |

  # 3. Map the grouped arrays to the expected output format
  map({
    "email": $email,
    "passkeys": {
      "user_handle": .[0].user_handle,
      "credentials": [
        .[] | {
          "key_id": .key_id,
          "public_key": .public_key,
          "relying_party_identifier": .relying_party_identifier,
          "credential_device_type": .credential_device_type,
          "aaguid": .aaguid,
          "user_agent": .user_agent,
          "transports": .transports,
          "credential_backed_up": .credential_backed_up
        } | with_entries(select(.value != null))
      ]
    }
  })
'