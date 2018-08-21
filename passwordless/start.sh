#!/bin/bash

#!/bin/bash

set -eo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})


function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-r connection] [-R response_type] [-f flow] [-u username] [-s scope] [-p prompt] [-m|-C|-o|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -a audiance    # Audience
        -r realm       # Connection (email or sms)
        -R types       # code or link
        -f flow        # OAuth2 flow type (implicit,code)
        -u callback    # callback URL (default ${AUTH0_REDIRECT_URI})
        -s scopes      # comma separated list of scopes (default is "${AUTH0_SCOPE}")
        -p prompt      # prompt type: none, silent, login
        -C             # copy to clipboard
        -m             # Management API audience
        -o             # Open URL
        -b browser     # Choose browser to open (firefox, chrome, safari)
        -P             # Preview mode 
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -s offline_access -o
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare email=''

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:c:a:r:R:f:u:p:s:b:mCPohv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        a) AUTH0_AUDIENCE=${OPTARG};;
        r) AUTH0_CONNECTION=${OPTARG};;
        R) AUTH0_RESPONSE_TYPE=`echo ${OPTARG} | tr ',' ' '`;;
        f) opt_flow=${OPTARG};;
        u) email=${OPTARG};;
        p) AUTH0_PROMPT=${OPTARG};;
        s) AUTH0_SCOPE=`echo ${OPTARG} | tr ',' ' '`;;
        C) opt_clipboard=1;;
        o) opt_open=1;; 
        P) opt_preview=1;; 
        m) opt_mgmnt=1;;
        b) opt_browser="-a ${OPTARG} ";;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }
[[ -z "${email}" ]] && { echo >&2 "ERROR: email undefined"; usage 1; }

#declare -r client_id='aIioQEeY7nJdX78vcQWDBcAqTABgKnZl'
#declare -r email='somebody@gmail.com'

declare data=$(cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}", 
    "connection":"email", 
    "email":"${email}", 
    "send":"link", 
    "authParams":{"scope": "openid email","state": "SOME_STATE", "response_type" : "code"}
}
EOL
)

curl --request POST \
  --url "https://${AUTH0_DOMAIN}/passwordless/start" \
  --header 'content-type: application/json' \
  --data "${data}"

