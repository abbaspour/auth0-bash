#!/bin/bash

set -eo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})
. ${DIR}/.env

curl -I -X OPTIONS https://${AUTH0_DOMAIN}/co/authenticate
