export client_id=XXXXX

Enrollment Steps 
================

Authenticator App
-----------------
1. ./01-start-flow.sh -t amin01@au -c $client_id -m -u email -p XXXX
2. ./02-start-associate.sh -t amin01@au -m $mfa_token -a otp
3. Open QA scan QR code
4. ./03-complete-challenge.sh -t amin01@au -c $client_id -m $mfa_token -a otp -b OTPCODE


SMS
---
1. ./01-start-flow.sh -t amin01@au -c $client_id -m -u email -p XXXX
2. ./02-start-associate.sh -t amin01@au -m $mfa_token -n +61450445271
3. Get SMS code 
4. ./03-complete-challenge.sh -t amin01@au -c $client_id -m $mfa_token -a oob -o $oob_code -b SMSCODE

Challenge Steps
===============

Authenticator App
-----------------
1. ./01-start-flow.sh -t amin01@au -c $client_id -m -u email -p XXXX
2. ./03-complete-challenge.sh -t amin01@au -c $client_id -m $mfa_token -a otp -b OTPCODE


SMS
---
1. ./01-start-flow.sh -t amin01@au -c $client_id -m -u email -p XXXX
2. ./02-mfa-challenge.sh -t amin01@au -c $client_id -m $mfa_token -a oob
3. ./03-complete-challenge.sh -t amin01@au -c $client_id -m $mfa_token -a oob -o $oob_code -b SMSCODE

