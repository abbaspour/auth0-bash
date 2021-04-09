#!/usr/bin/env bash

set -euo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-m mail] [-c client] [-o organisation] [-r connection] [-R role] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -n name     # inviter name
        -m mail     # Invitation mail
        -c id       # client_id
        -o org_id   # organisation_id
        -r conn_id  # realm connection_id
        -R role_od  # role
        -t ttl      # TTL in second. this value defaults to 604800 seconds (7 days). Max value: 2592000 seconds (30 days).
        -S          # silent, do not send invite
        -h|?        # usage
        -v          # verbose

eg,
     $0 -o org_123 -m someone@somewhere.com -c c_xyz -r role_xxx -n "Mr.Lova Lova"
END
    exit $1
}

declare name='Auth0 Bash'
declare organisation=''
declare mail=''
declare client=''
declare connection=''
declare role=''
declare send_invitation_email=true
declare -i ttl=604800

while getopts "e:a:n:m:c:o:r:R:t:Shv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        a) access_token=${OPTARG};;
        n) name=${OPTARG};;
        o) organisation=${OPTARG};;
        m) mail=${OPTARG};;
        c) client=${OPTARG};;
        r) connection=${OPTARG};;
        R) role=${OPTARG};;
        t) ttl=${OPTARG};;
        S) send_invitation_email=false;;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${organisation}" ]] && { echo >&2 "ERROR: organisation undefined."; usage 1; }
[[ -z "${mail}" ]] && { echo >&2 "ERROR: mail undefined."; usage 1; }
[[ -z "${client}" ]] && { echo >&2 "ERROR: client undefined."; usage 1; }
[[ -z "${connection}" ]] && { echo >&2 "ERROR: connection undefined."; usage 1; }
[[ -z "${role}" ]] && { echo >&2 "ERROR: role undefined."; usage 1; }

readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

readonly BODY=$(cat <<EOL
{
  "inviter": {
    "name": "${name}"
  },
  "invitee": {
    "email": "${mail}"
  },
  "client_id": "${client}",
  "connection_id": "${connection}",
  "app_metadata": {},
  "user_metadata": {},
  "ttl_sec": ${ttl},
  "roles": [
    "${role}"
  ],
  "send_invitation_email": ${send_invitation_email}
}
EOL
)

curl -H "Authorization: Bearer ${access_token}" \
  --url "${AUTH0_DOMAIN_URL}api/v2/organizations/${organisation}/invitations" \
  --header 'content-type: application/json' \
  --data "${BODY}"

