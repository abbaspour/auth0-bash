#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which wt > /dev/null || { echo >&2 "wt-cli not installed. run: npm install -g wt-cli"; exit 1; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant]
        -e file        # .env file location (default cwd)
        -t tenant      # tenant@region
        -8             # node v8 runtime (default)
        -4             # node v4 runtime (legacy)
        -b browser     # Choose browser to open (firefox, chrome, safari)
        -D             # Dry-run
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au
END
    exit $1
}


[[ -f ${DIR}/.env ]] && . ${DIR}/.env

declare runtime='8'
declare tenant=''
declare dry=''

while getopts "e:t:D48hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) tenant=${OPTARG};;
        D) dry='echo ';;
        4) runtime='';;
        8) runtime='8';;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${tenant}" ]] && { echo >&2 "ERROR: tenant undefined"; usage 1; }

declare -r region=$(echo ${tenant} | awk -F@ '{print $2}')
declare -r container=$(echo ${tenant} | awk -F@ '{print $1}')

declare sandbox="sandbox${runtime}"
declare profile="${container}"

[[ -n "${region}" ]] && { sandbox+="-${region}"; profile+="-${region}"; }

#profile+="${runtime}"
declare -r wt_url="https://${sandbox}.it.auth0.com"

${dry} wt init --container "${container}" --url "${wt_url}" -p "${profile}" --auth0

