# mTLS 

reference: https://docs.google.com/document/d/1E6jj11C72paoilTWWkoemqHsuuyZlhTjcfngy32gDIE/edit?usp=sharing

## Client Authentication 

### 1. Get Management Access Token
```bash
eval `./login/export-management-at.sh`
./jwt/dump.sh
```

Required scopes are:
* `create:custom_domains`
* `read:custom_domains`
* `create:clients`
* `update:clients`
* `update:client_credentials`
* `update:client_keys`
* `update:tenant_settings`


### 2. Enable Custom Domain Name
```bash
export CNAME_API_KEY=xxxx
export EDGE_LOCATION=yyyy
```

### 3. Enable Endpoint Aliases
```bash
cd tenant
./set-tenant-flag.sh -f enable_endpoint_aliases -s true -c mtls
curl -s -H "cname-api-key: ${CNAME_API_KEY}" \
  https://${EDGE_LOCATION}/.well-known/openid-configuration | \
  jq .mtls_endpoint_aliases 
```

### 4. Make a Self-Signed Key Pair
```bash
cd ca
./self-sign.sh -n mtls-m2m
```

### 5. Create mTLS client credentials and Patch Client to Accept it
```bash
export CLIENT_ID='xxx' # create M2M client from the manage dashboard and assign audience and scopes
cd clients
./create-client-credential.sh -i ${CLIENT_ID} -p ../ca/mtls-m2m-cert.pem \
  -t x509_cert -n "mtls cred 1" # collect credential ID
./set-client-credential.sh -i ${CLIENT_ID} -c cred_xxx_from_prev_step  -t self_signed_tls_client_auth
```

### 6. (Optional) Enable Token Binding on Client
```bash
cd clients
./set-token-binding.sh -i ${CLIENT_ID}
```

### 7. Test Client Credentials Exchange
```bash
cd ../login
./client-credentials.sh -i ${CLIENT_ID} -a sample.api \
  -d ${EDGE_LOCATION} -n ${CNAME_API_KEY} \
  -c ../ca/mtls-m2m-cert.pem
```

## 8. Check Token Binding (if enabled)
```bash
export JWT='access_token_from_prev_step'
../jwt/dump.sh ${JWT} | jq -r '.cnf."x5t#S256"' 
../ca/thumbprint.sh -f ../ca/mtls-m2m-cert.pem # two values should match 
``` 