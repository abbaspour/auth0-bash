#!/bin/bash

set -euo pipefail

declare AUTH0_CONNECTION='Username-Password-Authentication'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-u username] [-p password] [-c connection] [-m mail] [-M phone_number] [-i user_id] [-V|-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -u username # username
        -m email    # email
        -M number   # phone_number (switched connection to SMS)
        -p password # password
        -c realm    # connection (defaults to "${AUTH0_CONNECTION}")
        -i user_id  # (optional) user ID
        -V          # Mark as email/phone verififed
        -s          # send verify email
        -U k:v      # user_metadata key/value
        -A k:v      # app_metadata key/value
        -h|?        # usage
        -v          # verbose

eg,
     $0 -u somebody -m somebody@gmail.com -p ramzvorood
END
    exit $1
}

declare password=''
declare username=''
declare email=''
declare phone_number=''
declare verified_flag=''
declare send_verify_email=''
declare user_id=''

declare -a user_metadata=()
declare -a app_metadata=()

while getopts "e:a:u:m:M:p:c:i:U:A:Vshv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        u) username=${OPTARG};;
        m) email=${OPTARG};;
        M) phone_number=${OPTARG};;
        p) password=${OPTARG};;
        c) AUTH0_CONNECTION=${OPTARG};;
        i) user_id=${OPTARG};;
        U) user_metadata+=(${OPTARG});;
        A) app_metadata+=(${OPTARG});;
        V) verified_flag='1';;
        s) send_verify_email='1';;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z ${access_token+x} ]] && { echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"; exit 1; }
declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

#randomId() { for i in {0..20}; do echo -n $(( RANDOM % 10 )); done; }
#declare user_id=$(randomId)

declare user_id_field=''; [[ -n "${user_id}" ]] && user_id_field="\"user_id\": \"${user_id}\","
declare password_field=''; [[ -n "${password}" ]] && password_field="\"password\": \"${password}\","
declare username_field=''; [[ -n "${username}" ]] && username_field="\"username\": \"${username}\","
declare email_field=''; [[ -n "${email}" ]] && email_field="\"email\": \"${email}\","
declare verify_email_field=''; [[ -n "${verified_flag}" ]] && verify_email_field="\"verify_email\": true,"
declare phone_number_field=''; [[ -n "${phone_number}" ]] && { phone_number_field="\"phone_number\": \"${phone_number}\","; AUTH0_CONNECTION='sms'; }

declare verified_field='';
if [[ -n "${verified_flag}" ]]; then
  if [[ ${AUTH0_CONNECTION} == 'sms' ]]; then verified_field="phone_verified:true,"
  else verified_field="\"email_verified\":true,"
  fi
fi

declare app_metadata_str=$(printf ",%s" "${app_metadata[@]}")
app_metadata_str=${app_metadata_str:1}

declare user_metadata_str=$(printf ",%s" "${user_metadata[@]}")
user_metadata_str=${user_metadata_str:1}

  #${verify_email_field}

declare BODY=$(cat <<EOL
{
  "connection": "${AUTH0_CONNECTION}",
  ${user_id_field}
  ${username_field}
  ${password_field}
  ${email_field}
  ${phone_number_field}
  ${user_id_field}
  ${verified_field}
  "app_metadata": {${app_metadata_str}},
  "user_metadata": {${user_metadata_str}}
}
EOL
)

echo $BODY

curl --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/users \
    --header 'content-type: application/json' \
    --data "${BODY}"
