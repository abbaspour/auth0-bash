#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-11-06
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
# Search clients via GET /api/v2/clients/search (Lucene syntax only)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

readonly MAX_FILTER_CLAUSES=5
readonly APP_TYPES=' native spa regular_web non_interactive resource_server express_configuration rms box cloudbees concur dropbox mscrm echosign egnyte newrelic office365 salesforce sentry sharepoint slack springcm zendesk zoom sso_integration oag '
readonly EXPECTED_SCOPES=("read:clients" "read:client_summary")
readonly LUCENE_SPECIALS='+-!(){}[]^"~*?:\/&| '

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-q lucene] [shortcut options] [paging options] [-v|-h]

  Raw query:
        -q lucene   # raw Lucene query, used as-is (wrapped in parentheses)

  Shortcuts (each becomes a Lucene clause; clauses are ANDed; values are escaped):
        -N name     # name contains, wildcard, min 3 chars  -> name:*<name>*
        -t app_type # native, spa, regular_web, ... ; generic = null -> app_type:<type> (generic: app_type:null)
        -1          # first-party clients only                -> is_first_party:true
        -3          # third-party clients only                -> is_first_party:false
        -i id       # client_id, exact                        -> client_id:<id>
        -E url      # external_client_id (CIMD URL), exact    -> external_client_id:<url>
        -o org_id   # client grant organization id            -> client_grant.organization_id:<id>
        -A bool     # client grant allow_any_organization     -> client_grant.allow_any_organization:<bool>
        -M key=val  # metadata key/value, repeatable          -> metadata.<key>:<val>

  Paging and projection:
        -n take     # results per page, 1-100 (default 50)
        -c cursor   # next-page cursor from a previous response (from)
        -s sort     # name | updated_at (ascending)
        -F fields   # comma-separated fields to include, max 50
        -x          # exclude the -F fields instead of including them

        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -h|?        # usage
        -v          # verbose

  The API allows at most ${MAX_FILTER_CLAUSES} filter clauses per query. Each shortcut and the -q query count as one clause.

eg,
     $0 -N example -t spa -1
     $0 -M tier=gold -n 20
END
    exit $1
}

# Escape Lucene special characters so user input is matched literally
function lucene_escape() {
    local input="$1" out='' c i
    for (( i = 0; i < ${#input}; i++ )); do
        c="${input:i:1}"
        if [[ "${LUCENE_SPECIALS}" == *"${c}"* ]]; then
            out+="\\${c}"
        else
            out+="${c}"
        fi
    done
    printf '%s' "${out}"
}

declare raw_query='' name='' app_type='' first_party='' client_id='' external_id=''
declare org_id='' allow_any_org='' take='' from='' sort='' fields='' opt_exclude='' opt_verbose=''
declare -a metadata_pairs=()

while getopts "e:a:q:N:t:13i:E:o:A:M:n:c:s:F:xhv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    q) raw_query=${OPTARG} ;;
    N) name=${OPTARG} ;;
    t) app_type=${OPTARG} ;;
    1) [[ "${first_party}" == false ]] && { echo >&2 "ERROR: -1 and -3 are mutually exclusive"; exit 1; }; first_party=true ;;
    3) [[ "${first_party}" == true ]] && { echo >&2 "ERROR: -1 and -3 are mutually exclusive"; exit 1; }; first_party=false ;;
    i) client_id=${OPTARG} ;;
    E) external_id=${OPTARG} ;;
    o) org_id=${OPTARG} ;;
    A) [[ "${OPTARG}" == true || "${OPTARG}" == false ]] || { echo >&2 "ERROR: -A must be 'true' or 'false'"; exit 1; }
       allow_any_org=${OPTARG} ;;
    M) metadata_pairs+=("${OPTARG}") ;;
    n) take=${OPTARG} ;;
    c) from=${OPTARG} ;;
    s) sort=${OPTARG} ;;
    F) fields=${OPTARG} ;;
    x) opt_exclude=1 ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }

# Scope check: the endpoint accepts read:clients or read:client_summary
declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare scope_ok=''
for expected in "${EXPECTED_SCOPES[@]}"; do
    [[ " ${AVAILABLE_SCOPES} " == *" ${expected} "* ]] && scope_ok=1
done
[[ -n "${scope_ok}" ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected one of: '${EXPECTED_SCOPES[*]}', Available: '${AVAILABLE_SCOPES}'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")

# Validate paging and projection options
if [[ -n "${app_type}" ]]; then
    [[ "${app_type}" == generic || "${APP_TYPES}" == *" ${app_type} "* ]] || { echo >&2 "ERROR: invalid -t app_type '${app_type}'"; exit 1; }
fi

if [[ -n "${take}" ]]; then
    [[ "${take}" =~ ^[0-9]+$ ]] && (( take >= 1 && take <= 100 )) || { echo >&2 "ERROR: -n take must be an integer from 1 to 100"; exit 1; }
fi

if [[ -n "${sort}" ]]; then
    [[ "${sort}" == name || "${sort}" == updated_at ]] || { echo >&2 "ERROR: -s sort must be 'name' or 'updated_at'"; exit 1; }
fi

if [[ -n "${fields}" ]]; then
    declare field_commas=${fields//[^,]/}
    (( ${#field_commas} < 50 )) || { echo >&2 "ERROR: -F allows at most 50 fields"; exit 1; }
elif [[ -n "${opt_exclude}" ]]; then
    echo >&2 "ERROR: -x requires -F"; exit 1
fi

# Build Lucene clauses from raw query and shortcuts
declare -a clauses=()

if [[ -n "${raw_query}" ]]; then
    clauses+=("(${raw_query})")
fi

if [[ -n "${name}" ]]; then
    (( ${#name} >= 3 )) || { echo >&2 "ERROR: -N name must be at least 3 characters for wildcard search"; exit 1; }
    clauses+=("name:*$(lucene_escape "${name}")*")
fi

if [[ "${app_type}" == generic ]]; then
    clauses+=("app_type:null")
elif [[ -n "${app_type}" ]]; then
    clauses+=("app_type:${app_type}")
fi

if [[ -n "${first_party}" ]]; then
    clauses+=("is_first_party:${first_party}")
fi

if [[ -n "${client_id}" ]]; then
    clauses+=("client_id:$(lucene_escape "${client_id}")")
fi

if [[ -n "${external_id}" ]]; then
    clauses+=("external_client_id:$(lucene_escape "${external_id}")")
fi

if [[ -n "${org_id}" ]]; then
    clauses+=("client_grant.organization_id:$(lucene_escape "${org_id}")")
fi

if [[ -n "${allow_any_org}" ]]; then
    clauses+=("client_grant.allow_any_organization:${allow_any_org}")
fi

for pair in "${metadata_pairs[@]}"; do
    [[ "${pair}" == *=* ]] || { echo >&2 "ERROR: -M expects key=value, got '${pair}'"; exit 1; }
    declare meta_key="${pair%%=*}"
    declare meta_value="${pair#*=}"
    [[ "${meta_key}" =~ ^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)?$ ]] || { echo >&2 "ERROR: -M key '${meta_key}' must be alphanumeric with at most one dot (2 levels)"; exit 1; }
    [[ -n "${meta_value}" ]] || { echo >&2 "ERROR: -M value for '${meta_key}' is empty"; exit 1; }
    clauses+=("metadata.${meta_key}:$(lucene_escape "${meta_value}")")
done

if (( ${#clauses[@]} > MAX_FILTER_CLAUSES )); then
    echo >&2 "ERROR: ${#clauses[@]} filter clauses given; the API allows at most ${MAX_FILTER_CLAUSES} per query"
    exit 1
fi

declare q=''
for clause in "${clauses[@]}"; do
    if [[ -n "${q}" ]]; then q+=" AND "; fi
    q+="${clause}"
done

# Request parameters
declare -a params=(--data-urlencode "parser=lucene")
if [[ -n "${q}" ]]; then params+=(--data-urlencode "q=${q}"); fi
if [[ -n "${take}" ]]; then params+=(--data-urlencode "take=${take}"); fi
if [[ -n "${from}" ]]; then params+=(--data-urlencode "from=${from}"); fi
if [[ -n "${sort}" ]]; then params+=(--data-urlencode "sort=${sort}"); fi
if [[ -n "${fields}" ]]; then
    params+=(--data-urlencode "fields=${fields}")
    if [[ -n "${opt_exclude}" ]]; then
        params+=(--data-urlencode "include_fields=false")
    else
        params+=(--data-urlencode "include_fields=true")
    fi
fi

if [[ -n "${opt_verbose}" ]]; then echo >&2 "q: ${q:-<none>}"; fi

declare response http_code body
response=$(curl -sS -G -w '\n%{http_code}' -H "Authorization: Bearer ${access_token}" --url "${AUTH0_DOMAIN_URL}api/v2/clients/search" "${params[@]}")
http_code=$(tail -n 1 <<< "${response}")
body=$(sed '$d' <<< "${response}")

if [[ "${http_code}" != 2* ]]; then
    echo >&2 "ERROR: HTTP ${http_code}"
    case "${http_code}" in
    414) echo >&2 "query string too long; refine the search" ;;
    503) echo >&2 "search timed out (2 second limit); simplify the query" ;;
    esac
    if [[ -n "${body}" ]]; then echo >&2 "${body}"; fi
    exit 1
fi

jq '.' <<< "${body}"

#declare next_cursor
#next_cursor=$(jq -r '.next // empty' <<< "${body}")
#if [[ -n "${next_cursor}" ]]; then echo >&2 "next cursor (-c): ${next_cursor}"; fi
