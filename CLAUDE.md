# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of Bash scripts for interacting with Auth0's Management API and Authentication API. No build system — scripts are run directly.

## Dependencies

Required: `curl`, `jq`, `openssl`, `base64`

## Running Scripts

```bash
export access_token='YOUR_MGMT_API_TOKEN'
./users/list-users.sh -v
./users/create-user.sh -c Username-Password-Authentication -u user@example.com -p pass
```

Get a Management API token: Auth0 Dashboard → Applications → APIs → Auth0 Management API → API Explorer.

## Architecture

### Access Token Pattern

All Management API scripts share this three-step flow:

1. **Accept token** via `-a` flag or `access_token` env var
2. **Validate scope** by decoding the JWT:
   ```bash
   declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
   [[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope"; exit 1; }
   ```
3. **Extract domain** from the token's `iss` claim:
   ```bash
   declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")
   ```

### Script Structure (every script follows this order)

1. `#!/usr/bin/env bash` + `set -eo pipefail`
2. `command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }` checks
3. `usage()` heredoc
4. `getopts` loop
5. Parameter validation
6. Scope validation (Management API scripts)
7. `curl` API call piped to `jq`

### Common Parameters (maintain consistency)

| Flag | Meaning |
|------|---------|
| `-e <file>` | Source `.env` file |
| `-a <token>` | Access token |
| `-t <tenant>` | Short notation: `tenant@region` → `tenant.region.auth0.com` |
| `-d <domain>` | Full domain |
| `-c <connection>` | Connection/realm name |
| `-i <id>` | Resource ID |
| `-f <file>` | JSON file for request body |
| `-D <domain>` | Custom domain (adds `auth0-custom-domain` header) |
| `-v` | Verbose mode |

Tenant conversion: `t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.')`

### JSON Body Construction

Use heredoc with conditional fields:
```bash
declare email_field=''
[[ -n "${email}" ]] && email_field="\"email\": \"${email}\","

declare BODY=$(cat <<EOL
{
  "connection": "${AUTH0_CONNECTION}",
  ${email_field}
  "required_field": "value"
}
EOL
)
```

## Code Style

- `set -eo pipefail` (prefer `-euo pipefail` for stricter scripts)
- `$(command)` not backticks
- `"${variable}"` — always quote variables
- `[[ ]]` not `[ ]` for conditionals
- `declare` / `readonly` for variable declarations
- Must work on both Linux and macOS — no `gsed`, `ggrep`, etc.

## Adding a New Script

1. Copy an existing script from the same feature area
2. Update header (date, description)
3. Modify `usage()`, `getopts`, expected scope, and API endpoint
4. Test manually: read operations first, then write; use `-v` for debugging

## Directory Organization

**Management API:** `users/`, `clients/`, `connections/`, `roles/`, `organizations/`, `actions/`, `rules/`, `branding/`, `email-template/`, `attack-protection/`, `tenant/`

**Auth Flows:** `passwordless/`, `multifactor/`, `saml/`, `co/` (PAR), `consent/`, `delegation/`

**Utilities:** `tools/` (JWT), `ca/` (certs), `jobs/` (import/export), `logs/`, `asp/` (client assertions)
