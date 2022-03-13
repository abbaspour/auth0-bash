
## PBKDF2 Sample Data 

| Hashing | Iteration | Key Length | Salt | Password | PHC Hash |
|---------|-----------|------------| ---- | ---- | ---- |
| sha256  | 216000    | 32         | Y0JQSUhNcVZKUVBq |  pleasework | $pbkdf2-sha256$i=216000,l=32$Y0JQSUhNcVZKUVBq$OVur66V8LRGQVMrcUznEJMrdIJvCe7JfNXTVzzyEQVE |
| sha256  | 10000     | 32         | wJuJqLoUFsdXa8k3sFhRlA== | Test@123 | $pbkdf2-sha256$i=10000,l=32$wJuJqLoUFsdXa8k3sFhRlA$2waKCbPhZzL+RjWMQqvA1jpb+j56jTAXcNmRD9UTekU |
| sha1    | 10000     | 20         | wJuJqLoUFsdXa8k3sFhRlA== | Test@123 | $pbkdf2-sha1$i=10000,l=20$wJuJqLoUFsdXa8k3sFhRlA$XMGVWTbeKf4Xd+CGiuEZde8x7QA |


### Gigya Example

* Email - onelogintest1005@yopmail.com 
* Password - Test@123

```json
{
  "password": {
    "hash": "XMGVWTbeKf4Xd+CGiuEZde8x7QA=",
    "hashSettings": {
      "algorithm": "pbkdf2",
      "rounds": 10000,
      "salt": "wJuJqLoUFsdXa8k3sFhRlA=="
    }
  }
}
```

Matching Auth0 bulk import

```json
[
  {
    "email": "onelogintest1005@yopmail.com",
    "email_verified": false,
    "custom_password_hash": {
      "algorithm": "pbkdf2",
      "hash": {
        "value": "$pbkdf2-sha1$i=10000,l=20$wJuJqLoUFsdXa8k3sFhRlA$XMGVWTbeKf4Xd+CGiuEZde8x7QA",
        "encoding": "utf8"
      }
    }
  }
]
