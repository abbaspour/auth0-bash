`# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Auth0 Bash Scripts is a comprehensive collection of Bash scripts for interacting with Auth0's Management API and Authentication API. The project provides command-line tools for managing Auth0 resources and testing authentication flows.

## Core Architecture

### Access Token Pattern
Almost all scripts follow this pattern for Auth0 Management API authentication:

1. **Token Extraction**: Access tokens can be provided via `-a` flag or `access_token` environment variable
2. **Scope Validation**: Scripts decode the JWT to validate required scopes before making API calls:
   ```bash
   declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
   declare -r EXPECTED_SCOPE="read:clients"
   [[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope"; exit 1; }
   ```
3. **Domain Extraction**: Auth0 domain is extracted from the token's `iss` claim:
   ```bash
   declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")
   ```

### Script Structure Pattern
All scripts follow a consistent structure:

1. Shebang: `#!/usr/bin/env bash`
2. Header comment block with author, date, and MIT license
3. Error handling: `set -eo pipefail` (some use `set -euo pipefail`)
4. External command checks: `command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }`
5. `usage()` function with heredoc for help text
6. `getopts` loop for argument parsing
7. Parameter validation
8. Token scope validation (for Management API scripts)
9. API request with curl
10. Output formatting (typically with `jq`)

### Directory Organization
The repository is organized by Auth0 feature area:

**Management API Operations:**
- `users/`, `clients/`, `connections/`, `roles/`, `organizations/` - CRUD operations for Auth0 resources
- `actions/`, `rules/` - Extensibility features
- `branding/`, `email-template/` - UI customization
- `attack-protection/`, `anomaly/` - Security features
- `tenant/` - Tenant-level configuration

**Authentication Flows:**
- `passwordless/` - Email/SMS OTP authentication
- `multifactor/` - MFA enrollment and challenge flows
- `saml/` - SAML SP and IdP configurations
- `co/` - Pushed Authorization Requests (PAR)
- `consent/` - OAuth consent flows
- `delegation/` - Token delegation

**Utilities:**
- `tools/` - JWT creation and manipulation
- `ca/` - Certificate authority utilities (self-signed certs, thumbprints)
- `jobs/` - User import/export, CSV generation
- `logs/` - Log searching and export
- `asp/` - Authorization Service Provider (client assertions)

### Common Script Parameters
Maintain consistency when adding or modifying scripts:

- `-e <file>`: Source .env file for environment variables
- `-a <token>`: Access token (Management API)
- `-t <tenant>`: Tenant in format `tenant@region` (converts to `tenant.region.auth0.com`)
- `-d <domain>`: Fully qualified Auth0 domain
- `-c <connection>`: Connection/realm name
- `-i <id>`: Resource ID (user_id, client_id, connection_id, etc.)
- `-f <file>`: JSON file for request body
- `-v`: Verbose mode (typically sets `opt_verbose=1`)
- `-h|-?`: Display usage information
- `-D <domain>`: Custom domain (sets `auth0-custom-domain` header)

### Tenant/Domain Conversion
Scripts support both short tenant notation and full domains:
- `-t amin01@au` → `amin01.au.auth0.com`
- `-d tenant.region.auth0.com` → use as-is

This is implemented as:
```bash
t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
d) AUTH0_DOMAIN=${OPTARG} ;;
```

## Testing Scripts

Since there are no automated tests, follow this manual testing approach:

1. **Get a Management API Token**:
   - Visit Auth0 Dashboard → Applications → APIs → Auth0 Management API → API Explorer
   - Copy the token with appropriate scopes
   - Set environment: `export access_token='YOUR_TOKEN'`

2. **Test Read Operations First**: Before testing create/update/delete, verify list/get operations work

3. **Use Verbose Mode**: Add `-v` flag for debugging curl requests

4. **Validate Error Cases**: Test with missing parameters, invalid tokens, insufficient scopes

5. **Check JSON Output**: Ensure `jq` formatting works correctly

## Code Style Requirements

### Bash Best Practices
- Use `set -eo pipefail` (or `set -euo pipefail`) at the top of scripts
- Use `$(command)` instead of backticks
- Quote all variables: `"${variable}"` not `$variable`
- Use `[[ ]]` for conditionals instead of `[ ]`
- Use `readonly` for constants: `readonly DIR=$(dirname "${BASH_SOURCE[0]}")`
- Use `declare` for variable declarations with clear scope

### Portability Requirements
- Code must work on both Linux and macOS
- Use Bash 5 features when available
- Prefer portable commands: `jq`, `openssl`, `sed`, `awk`, `curl`
- Avoid platform-specific commands (no `gsed`, `ggrep`, etc.)

### JSON Body Construction
Use heredoc for JSON bodies (maintains readability):
```bash
declare BODY=$(cat <<EOL
{
  "connection": "${AUTH0_CONNECTION}",
  ${optional_field}
  "required_field": "value"
}
EOL
)
```

For conditional fields, set variables with trailing comma:
```bash
declare email_field=''
[[ -n "${email}" ]] && email_field="\"email\": \"${email}\","
```

### Error Messages
Provide actionable error messages:
```bash
[[ -z ${access_token+x} ]] && {
  echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"
  exit 1
}
```

## Special Features

### Custom Domain Support
Scripts support custom domains via `-D` flag:
```bash
-D) custom_domain="auth0-custom-domain: ${OPTARG}" ;;
...
curl ... --header "${custom_domain}" ...
```

### Scope Validation
Management API scripts validate JWT scopes before making requests. Required scopes are documented in usage functions and validated inline.

### Environment Files
Scripts can source `.env` files with `-e` flag for bulk configuration:
```bash
source .env
# Sets: access_token, AUTH0_DOMAIN, AUTH0_CLIENT_ID, etc.
```

## Common Development Patterns

### Adding a New Script
1. Copy an existing script from the same feature area as a template
2. Update the header (date, description)
3. Modify the `usage()` function with correct parameters
4. Update the `getopts` string and case statements
5. Change the expected scope and API endpoint
6. Update JSON body construction
7. Test manually with valid credentials

### Modifying API Calls
When updating scripts for API changes:
1. Check Auth0 Management API documentation for the endpoint
2. Update required scopes in validation
3. Modify JSON body structure
4. Update usage examples
5. Test with appropriate permissions

### Working with JWT Tokens
For scripts that create or manipulate JWTs, see `tools/mk-id_token.sh` for examples of:
- RS256/HS256 signing
- Custom claims
- Header construction

## Dependencies
Required external commands (check with `command -v`):
- `curl`: All API requests
- `jq`: JSON parsing and formatting
- `openssl`: Certificate and cryptographic operations (in `ca/`, `saml/`, token scripts)
- `base64`: Encoding/decoding (especially for JWT handling)

## Project-Specific Notes

### No Formal Testing Framework
The project intentionally has no automated tests. When making changes:
1. Test manually with appropriate Auth0 credentials
2. Verify output format matches existing patterns
3. Test error conditions (missing params, invalid tokens)
4. Ensure cross-platform compatibility (test on both macOS and Linux if possible)

### Argument Consistency
Try to keep arguments consistent across scripts. If adding a new parameter, check similar scripts to see if there's an established pattern (e.g., `-i` for IDs, `-c` for connections).

### JSON vs Command-Line Input
Scripts accept either:
- Individual parameters via flags (e.g., `-u username -m email`)
- JSON file via `-f` flag for complex objects

Prefer individual flags for simple operations, JSON files for complex configurations.
