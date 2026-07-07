#!/usr/bin/env bash

set -eo pipefail

####
# how to use this? eval `./export-teams-at.sh`
####

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

readonly active_env="${DIR}/.env-teams"

[[ -f "${active_env}" ]] || { echo >&2 "ERROR: no active .env file found"; exit 3; }

declare access_token
access_token=$("${DIR}/../../oidc-bash/client-credentials.sh" -e "${active_env}" | jq -r .access_token)
readonly access_token

echo "export access_token='${access_token}'"
