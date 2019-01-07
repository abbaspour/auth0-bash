ASP Steps
=========

A. API
------
1. build a set of private/public keys
```bash
cd ../ca
./self-sign.sh -n backend-api
```

2. create resource-server with arbitrary API
```bash
cd ../resource-server/
./create-rs.sh  -i https://backend.api -n "Backend API" -s read:data,write:data
```

3. register public key against verificationKey of your resource server 
```bash
./add-verification-key.sh -i 5c20475819a2bc74962784c6 -k backend-api -f ../ca/backend-api-public.pem
```

B. M2M Client
-------------
1. build m2m 
```bash
cd ../clients
./create-client.sh -n "M2M for ASP" -t non_interactive
```

2. grant client_credentials from prev step against management API with below scopes 
```bash
./create-client-grants.sh -i bMZEeDKSzQkoDpJiKgZuhTHgRzZ4VFRE -m \
 -s create:user_application_passwords,read:user_application_passwords,delete:user_application_passwords
```

3. Figure out what's client_secret of this new client
```bash
./list-clients.sh 
```

C. Register
-----------
1. Use M2M client to get a management API access_token

```bash
cd ../login
export access_token=$(./client-credentials.sh -t tenant@region \
    -c bMZEeDKSzQkoDpJiKgZuhTHgRzZ4VFRE -x XXXX -m | jq -r .access_token)
```

2. register ASP against a user with your API
```bash
cd ../asp
./create-asp.sh  -i 'auth0|5b5fb9702e0e740478884234' \
    -a https://backend.api -n "My ASP for Backend API" \
    -s read:data,write:data
```

Record `value`. It's user's ASP against your API.

D. Validate
-----------
1. create a client-assertion jwt using private key in step A-1 and with `sub` equal to API identifier in step A-2 & `aud` to auth0 tenant

```bash
cd ../asp
./client-assertion.sh -t tenant@region -a https://backend.api -k backend-api -f ../ca/backend-api-private.pem
```

2. Introspect ASP 
```bash
cd ../token
./introspect.sh -t tenant@region -a 'ASP-from-C-2'  -c clients
```

