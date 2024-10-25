#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-08-19
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-t type] [-s string] [-v|-h]
        -t type        # type of string; private or certificate (default)
        -s string      # key string
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t private -s MIIEogIBAAKCAQEAp8LGsjYjsNjczgwB....KtPR8uLU=
END
    exit $1
}

# Default type is certificate
type="CERTIFICATE"
input_string=""

# Function to format the string into PEM format
format_x509_string() {
    local header="-----BEGIN $1-----"
    local footer="-----END $1-----"
    local formatted_string=$(echo "$2" | tr -d ' ' | fold -w 64)
    echo -e "${header}\n${formatted_string}\n${footer}"
}

while getopts ":t:s:h?" opt; do
  case ${opt} in
    t)
      if [[ "$OPTARG" == "private" ]]; then
        type="PRIVATE KEY"
      elif [[ "$OPTARG" != "certificate" ]]; then
        echo "Invalid type specified. Use 'private' or 'certificate'."
        usage 1
      fi
      ;;
    s) input_string=$OPTARG;;
    h | \? ) usage 0;;
    *) usage 1 ;;
  esac
done

# Check if input string is provided
if [ -z "$input_string" ]; then
  echo "Error: Input string (-s) is required"
  usage 1
fi

# Call the format function
format_x509_string "$type" "$input_string"
