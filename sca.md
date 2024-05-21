# Strong Customer Authentication (SCA)

## Setup
1. Create a resource server or follow instructions in [Configure Rich Authorization Requests](https://auth0.com/docs/get-started/apis/configure-rich-authorization-requests) to enable consent policy 

```bash
./create-rs.sh -n 'SCA Payment API' -i 'https://payments.api/' -p "transactional-authorization-with-mfa" -d payment_initiation,money_transfer
```

2. Create a rich PAR request

```bash
cd login
./authorize.sh -C -c ED27SLierWMOj8SAsTY5H87fXsq1gRLO -a 'https://payments.api/' \
  -P -K ../ca/jar-test-private.pem -k qLW4Jbo7jD-e_WAFzg40aKsHTFQeGK2NT0wWnd0cCfw \
  -D '[
    {"type":"payment_initiation",
     "actions":["list_accounts","read_balances","read_transactions"],
     "locations":["https://example.com/accounts"]
    }]' 

```

Sample event in Actions
```json
{
  "transaction": {
    "acr_values": [],
    "linking_id": "mmP9ZpUWJlrO4_yGtMEO4P7STlA",
    "requested_authorization_details": [
      {
        "actions": [
          "list_accounts",
          "read_balances",
          "read_transactions"
        ],
        "locations": [
          "https://example.com/accounts"
        ],
        "type": "payment_initiation"
      }
    ]
  }
}
```