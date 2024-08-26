#!/usr/bin/env bash

# Note: This method is no longer supported.
# use Actions: https://auth0.com/docs/authenticate/protocols/saml/saml-sso-integrations/sign-and-encrypt-saml-requests#change-the-signing-key-for-saml-responses

set -eo pipefail

command -v awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-A access_token] [-i client_id] [-m|-v|-h]
        -e file         # .env file location (default cwd)
        -A token        # access_token. default from environment variable
        -i id           # client_id
        -p pub.pem      # signing public key
        -k prv.pem      # signing private key
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i cgr_hoNhUx20xV7p6zqE -p public.pem -k private.pem
END
    exit $1
}

declare client_id=''
declare cert_file=''
declare key_file=''

while getopts "e:A:i:p:k:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        A) access_token=${OPTARG};;
        i) client_id=${OPTARG};;
        p) cert_file=${OPTARG};;
        k) key_file=${OPTARG};;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined."; usage 1; }


declare signing_keys=''

[[ -n ${cert_file} && -n ${key_file} ]] && {
  declare -r cert_txt=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "${cert_file}")
  declare -r key_txt=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "${key_file}")
  signing_keys=$(cat <<EOL
    "signing_keys": [ {
        "cert": "${cert_txt}",
        "key": "${key_txt}"
      }
    ]
EOL
)
}

declare BODY=$(cat <<EOL
{
  ${signing_keys}
}
EOL
)

echo $BODY

#exit

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}"

echo
