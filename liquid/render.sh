##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -euo pipefail

which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }
which jq > /dev/null || { echo >&2 "error: jq not found"; exit 3; }
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

function usage() {
    cat <<END >&2
USAGE: $0 [-e file] [-f file] [-v|-h]
        -e file        # JSON context file
        -f file        # Liquid script file
        -h|?           # usage
        -v             # verbose

eg,
     $0 -e context.json -f sms.liquid
END
    exit $1
}

declare contextFile=''
declare liquidFile=''
declare opt_verbose=0

while getopts "e:f:hv?" opt; do
    case ${opt} in
    e) contextFile=${OPTARG} ;;
    f) liquidFile=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${contextFile}" ]] && {
    echo >&2 "ERROR: Context file undefined"
    usage 1
}
[[ -z "${liquidFile}" ]] && {
    echo >&2 "ERROR: Liquid file undefined"
    usage 1
}

[[ -d "${DIR}/node_modules/liquidjs/" ]] || {
    echo >&2 "ERROR: missing module. Run: 'npm i liquidjs'"
    exit 2
}

cat <<EOL | node
const fs = require('fs');
const Liquid = require("liquidjs");
const engine = Liquid();

const context = JSON.parse(fs.readFileSync("${contextFile}"));

engine.renderFile("${liquidFile}", context).then(console.log);
EOL
