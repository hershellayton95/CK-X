#!/bin/bash
F=/tmp/exam/1/cert
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/1/cert is missing or empty"
  exit 1
fi
if ! head -1 "$F" | grep -q -- '-----BEGIN CERTIFICATE-----'; then
  echo "❌ /tmp/exam/1/cert does not start with a PEM certificate header"
  exit 1
fi
if ! tail -1 "$F" | grep -q -- '-----END CERTIFICATE-----'; then
  echo "❌ /tmp/exam/1/cert does not end with a PEM certificate footer"
  exit 1
fi
ACTUAL=$(tr -d '[:space:]' < "$F" | sha256sum | awk '{print $1}')
EXPECTED=a456b1fbc9ca4753d7b481088e3544bf77864294c38c3dcbd07fd17f915c903c
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "❌ /tmp/exam/1/cert does not contain the account-0027@internal client certificate"
  exit 1
fi
echo "✅ The decoded account-0027@internal client certificate is valid PEM"
exit 0
