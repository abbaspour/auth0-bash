## Steps

1. get api2 AT.
```bash
export access_token='HERE'
```

2. create source RS
```bash
cd resource-server
./create-rs.sh -i urn://source.api -n "Source API"   
```

3. enable TE on source API
```bash
./update-rs.sh -i source.rs.id -f token_exchange -s true
```
This returns a client_id and client_secret. We'll need them in step 5 and 8

4. Create target RS
```bash
./create-rs.sh -i urn://target.api -n "Target API" -s update:thing,read:thing  
```

5. Create Access Policy
```bash
cd ../access-policy
./create-access-policy.sh -c <source.api.client.id> -a urn://target.api -s read:thing 
```

6. Login with a valid user against. Can JWT.io to receive AT 
```bash
cd ../login
./authorize.sh -t login0@local.dev \
    -c <jwt.io-spa-client-id> \
    -R token \
    -a urn://source.api \
    -b firefox -o 
```

7. Login and get user's delegated AT

8. Execute exchange
```bash
./token-exchange -t login0@local.dev \
    -c <source.rs.client.id> \
    -x <source.rs.client.secret> \
    -a urn://target.api
    -s read:thing
    -i <user-AT>
```
