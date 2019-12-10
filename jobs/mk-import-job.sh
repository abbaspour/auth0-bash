#!/usr/bin/env bash

set -euo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-i file] [-o file]
        -f file       # input users CSV file
        -o file       # output JSON file
        -h|?          # usage
        -v            # verbose

eg,
     $0 -i users.csv -o users.json
END
    exit $1
}

declare csv_file=''

while getopts "f:o:hv?" opt
do
    case ${opt} in
        f) csv_file=${OPTARG};;
        o) exec > ${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${csv_file}" ]] && { echo >&2 "Error: missing input file"; exit 1; }

cat ${csv_file} | grep -v ^# | awk -e '
BEGIN{
    FS=","
    print "["
}

END {
    print "]"
}

{
    customer_id=$1
    username=$2
    account_no=$2
    email=$3
    if ($3 == "") { email = sprintf("%s@my.fake.company.com",account_no) }
    salt_field=""
    if ($6 != "") { salt_field=sprintf("\"salt\": { \"value\": \"%s\", \"encoding\": \"base64\", \"position\": \"prefix\" },\n", $6) }
    algorithm=$5
    hash=$7

    if (NR == 1) { print "{"; } else { print ",{"; }
    printf " \
        \"username\": \"%s\",\n \
        \"email\": \"%s\",\n \
        \"app_metadata\": {\n \
            \"customer_id\": \"%s\",\n \
            \"account_no\" : \"%s\"\n \
        },\n \
        \"custom_password_hash\": {\n \
            \"algorithm\": \"%s\",\n \
            %s \
            \"hash\": { \"value\": \"%s\", \"encoding\": \"base64\" } \n \
        }\n \
 }\n",username, email, customer_id, account_no, algorithm, salt_field, hash
}'
