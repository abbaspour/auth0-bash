#!/bin/bash

# Configuration
DB_URI="postgresql://keycloak:password@localhost:5432/keycloak"

# Predefined fixed values for the export
RP_ID="home.abbaspour.net"
DEVICE_TYPE="multi_device"

# Check for optional email argument
TARGET_EMAIL="$1"
WHERE_CLAUSE="WHERE c.TYPE = 'webauthn-passwordless'"

if [ -n "$TARGET_EMAIL" ]; then
    # Basic sanitization to prevent breaking the SQL string
    SAFE_EMAIL=$(echo "$TARGET_EMAIL" | tr -d "'")
    WHERE_CLAUSE="${WHERE_CLAUSE} AND u.email = '${SAFE_EMAIL}'"
fi

# 1. Fetch raw JSON blobs from PostgreSQL
RAW_DATA=$(psql "$DB_URI" -t -A -c "
    SELECT json_build_object(
        'email', u.email,
        'user_id', u.ID,
        'cred', c.credential_data::json
    )
    FROM user_entity u
    INNER JOIN credential c ON u.ID = c.USER_ID
    ${WHERE_CLAUSE};
")

# If no data is returned, output an empty JSON array and exit
if [ -z "$RAW_DATA" ]; then
    echo "[]"
    exit 0
fi

# 2. Transform into grouped JSON structure using jq
echo "$RAW_DATA" | jq -s \
  --arg rp_id "$RP_ID" \
  --arg dev_type "$DEVICE_TYPE" '

  # Helper function to convert Base64URL (unpadded) to Standard Base64 (padded)
  def to_standard_base64:
    gsub("-"; "+") | gsub("_"; "/") |
    . + if (length % 4 == 2) then "=="
        elif (length % 4 == 3) then "="
        else "" end;

  # Helper function to convert Standard Base64 to Base64URL (unpadded)
  def to_base64url:
    gsub("\\+"; "-") | gsub("/"; "_") | sub("=+$"; "");

  group_by(.email) | map({
    email: .[0].email,
    passkeys: {
      user_handle: (.[0].user_id | @base64 | to_base64url),
      credentials: map({
          key_id: (.cred.credentialId | to_base64url),
          public_key: (.cred.credentialPublicKey | to_standard_base64),
          relying_party_identifier: $rp_id,
          credential_device_type: $dev_type,
          aaguid: .cred.aaguid,
          transports: .cred.transports,
          credential_backed_up: (.cred.credentialBackedUp // false)
      })
    }
  })
'