

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-j job_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -j id       # job_id
        -h|?        # usage
        -v          # verbose

eg,
     $0 -j j_123
END
    exit $1
}

declare job_id=''

while getopts "e:a:j:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        j) job_id=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${job_id}" ]] && { echo >&2 "ERROR: job_id undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

curl -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/jobs/${job_id}

