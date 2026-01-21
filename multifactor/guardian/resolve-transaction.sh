#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-01-21
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

# Guardian Transaction Resolver
# Mimics Guardian.Android SDK's transaction resolution behavior
# Sends allow/reject decision to Auth0 Guardian MFA service

set -e

# Default values
CLIENT_NAME="Guardian.Shell"
CLIENT_VERSION="1.0.0"

# Usage function
usage() {
    cat << EOF
Usage: $0 -c CHALLENGE -d DOMAIN -i DEVICE_ID -k KEY_PATH -t TXTKN [-R REASON] [-a AUTH0_CLIENT]

Required arguments:
  -c CHALLENGE      Challenge value from push notification (sets JWT 'sub' claim)
  -d DOMAIN         Base domain/URL (e.g., 'tenant.auth0.com' or 'tenant.guardian.auth0.com')
  -i DEVICE_ID      Device identifier (sets JWT 'iss' claim)
  -k KEY_PATH       Path to RSA private key PEM file
  -t TXTKN          Transaction token from push notification

Optional arguments:
  -R REASON         Reject reason. If provided, rejects the transaction (auth0_guardian_accepted=false)
                    If omitted, allows the transaction (auth0_guardian_accepted=true)
  -a AUTH0_CLIENT   Custom Auth0-Client header value (base64-encoded JSON)
                    Default: {"name":"Guardian.Shell","version":"1.0.0"}
  -h                Show this help message

Examples:
  # Allow a transaction
  $0 -c "challenge_abc" -d "tenant.auth0.com" -i "device_123" -k ./private.pem -t "txtkn_xyz"

  # Reject a transaction with reason
  $0 -c "challenge_abc" -d "tenant.auth0.com" -i "device_123" -k ./private.pem -t "txtkn_xyz" -R "Suspicious login"

  # Using a Guardian hosted domain (no /appliance-mfa prefix needed)
  $0 -c "challenge_abc" -d "tenant.guardian.auth0.com" -i "device_123" -k ./private.pem -t "txtkn_xyz"

EOF
    exit 1
}

# Parse command line arguments
while getopts "c:d:i:k:t:R:a:h" opt; do
    case $opt in
        c) CHALLENGE="$OPTARG" ;;
        d) DOMAIN="$OPTARG" ;;
        i) DEVICE_ID="$OPTARG" ;;
        k) KEY_PATH="$OPTARG" ;;
        t) TXTKN="$OPTARG" ;;
        R) REASON="$OPTARG" ;;
        a) AUTH0_CLIENT="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option -$OPTARG" >&2; usage ;;
    esac
done

# Validate required parameters
if [[ -z "$CHALLENGE" ]] || [[ -z "$DOMAIN" ]] || [[ -z "$DEVICE_ID" ]] || [[ -z "$KEY_PATH" ]] || [[ -z "$TXTKN" ]]; then
    echo "Error: Missing required arguments" >&2
    usage
fi

# Check if key file exists
if [[ ! -f "$KEY_PATH" ]]; then
    echo "Error: Private key file not found: $KEY_PATH" >&2
    exit 1
fi

# Function to perform base64url encoding (URL-safe, no padding)
base64url_encode() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# Function to build the full URL with proper path handling
build_url() {
    local domain="$1"

    # Remove protocol if present
    domain="${domain#http://}"
    domain="${domain#https://}"

    # Remove trailing slash
    domain="${domain%/}"

    # Check if it's a Guardian hosted domain (*.guardian.*.auth0.com or *.guardian.auth0.com)
    if [[ "$domain" =~ guardian.*\.auth0\.com ]]; then
        # Guardian hosted domains don't need /appliance-mfa prefix
        echo "https://${domain}/api/resolve-transaction"
    elif [[ "$domain" =~ /appliance-mfa ]]; then
        # Domain already contains /appliance-mfa
        echo "https://${domain}/api/resolve-transaction"
    else
        # Custom domain needs /appliance-mfa prefix
        echo "https://${domain}/appliance-mfa/api/resolve-transaction"
    fi
}

# Build the full URL
FULL_URL=$(build_url "$DOMAIN")

# Determine if this is an allow or reject
if [[ -n "$REASON" ]]; then
    ACCEPTED="false"
else
    ACCEPTED="true"
fi

# Get current Unix timestamp
IAT=$(date +%s)
EXP=$((IAT + 30))

# Build JWT header
JWT_HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64url_encode)

# Build JWT payload
if [[ "$ACCEPTED" == "true" ]]; then
    # Allow transaction (no reason field)
    JWT_PAYLOAD=$(cat <<EOF | jq -c . | base64url_encode
{
  "iat": $IAT,
  "exp": $EXP,
  "aud": "$FULL_URL",
  "iss": "$DEVICE_ID",
  "sub": "$CHALLENGE",
  "auth0_guardian_method": "push",
  "auth0_guardian_accepted": true
}
EOF
)
else
    # Reject transaction (with reason)
    JWT_PAYLOAD=$(cat <<EOF | jq -c . | base64url_encode
{
  "iat": $IAT,
  "exp": $EXP,
  "aud": "$FULL_URL",
  "iss": "$DEVICE_ID",
  "sub": "$CHALLENGE",
  "auth0_guardian_method": "push",
  "auth0_guardian_accepted": false,
  "auth0_guardian_reason": "$REASON"
}
EOF
)
fi

# Create the signature base
SIGNATURE_BASE="${JWT_HEADER}.${JWT_PAYLOAD}"

# Sign with private key using RS256 (RSA with SHA-256)
JWT_SIGNATURE=$(echo -n "$SIGNATURE_BASE" | openssl dgst -sha256 -sign "$KEY_PATH" | base64url_encode)

# Construct final JWT
JWT="${SIGNATURE_BASE}.${JWT_SIGNATURE}"

# Generate Auth0-Client header if not provided
if [[ -z "$AUTH0_CLIENT" ]]; then
    AUTH0_CLIENT=$(echo -n "{\"name\":\"$CLIENT_NAME\",\"version\":\"$CLIENT_VERSION\"}" | base64url_encode)
fi

# Build request body
REQUEST_BODY=$(cat <<EOF | jq -c .
{
  "challenge_response": "$JWT"
}
EOF
)

# Print request details (for debugging)
echo "=== Guardian Transaction Resolution ===" >&2
echo "Action: $([ "$ACCEPTED" == "true" ] && echo "ALLOW" || echo "REJECT")" >&2
echo "URL: $FULL_URL" >&2
echo "Device ID: $DEVICE_ID" >&2
echo "Challenge: $CHALLENGE" >&2
[[ -n "$REASON" ]] && echo "Reason: $REASON" >&2
echo "Transaction Token: ${TXTKN:0:20}..." >&2
echo "" >&2
echo "Sending request..." >&2
echo "" >&2

# Send the request
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/guardian_response.txt \
    -X POST "$FULL_URL" \
    -H "Authorization: Bearer $TXTKN" \
    -H "Auth0-Client: $AUTH0_CLIENT" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY")

# Print response
echo "=== Response ===" >&2
echo "HTTP Status Code: $HTTP_CODE" >&2

if [[ -s /tmp/guardian_response.txt ]]; then
    echo "Response Body:" >&2
    cat /tmp/guardian_response.txt >&2
    echo "" >&2
fi

# Clean up
rm -f /tmp/guardian_response.txt

# Check if request was successful
if [[ "$HTTP_CODE" == "204" ]] || [[ "$HTTP_CODE" == "200" ]]; then
    echo "" >&2
    echo "✓ Transaction $([ "$ACCEPTED" == "true" ] && echo "allowed" || echo "rejected") successfully" >&2
    exit 0
else
    echo "" >&2
    echo "✗ Request failed with HTTP $HTTP_CODE" >&2
    exit 1
fi
