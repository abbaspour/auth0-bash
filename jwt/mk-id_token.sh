#!/usr/bin/env bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-t tenant] [-d domain] [-i iss] [-a audience] [-s sub] [-e exp] [-n nonce] [-o file]
        -t tenant      # tenant
        -d domain      # domain
        -i iss         # issuer
        -a aud         # audience / client_id
        -s sub         # user subject
        -e exp         # expiry in minutes (default is 1 day)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -a y4KJ1oOdLyx5lwILRInTbCCx221VCduh -s 'auth0|5b5e65d30368302c7d1223a6' -o id_token.json
END
    exit $1
}

declare iss=''
declare sub=''
declare aud=''
declare file=''
declare nonce_field=''
declare -r iat=`date +%s`
declare exp=`date -d "+1 days" +%s`
declare opt_verbose=0

while getopts "t:d:i:a:s:e:n:o:hv?" opt
do
    case ${opt} in
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`; iss="https://${AUTH0_DOMAIN}/";;
        d) iss="https://${OPTARG}/";;
        i) iss=${OPTARG};;
        a) aud=${OPTARG};;
        s) sub=${OPTARG};;
        e) exp=${OPTARG};;
        n) nonce_field="\"nonce\": \"${OPTARG}\",";;
        o) exec > ${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${iss}" ]] && { echo >&2 "Error: undefined iss"; usage 1; }
[[ -z "${aud}" ]] && { echo >&2 "Error: undefined aud"; usage 1; }
[[ -z "${sub}" ]] && { echo >&2 "Error: undefined sub"; usage 1; }

cat <<EOL
{
  "iss": "${iss}",
  "sub": "${sub}",
  "aud": "${aud}",
  ${nonce_field}
  "iat": ${iat},
  "exp": ${exp}
}
EOL

#{
#  "iss": "https://amin01.au.auth0.com/",
#  "sub": "auth0|5b5e65d30368302c7d1223a6",
#  "aud": "y4KJ1oOdLyx5lwILRInTbCCx221VCduh",
#  "iat": 1575512074,
#  "exp": 1575548074,
#  "nonce": "mynonce"
#}
