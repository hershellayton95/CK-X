#!/bin/bash
CERT=/etc/kubernetes/pki/apiserver.crt
F=/tmp/exam/14/expiration
if [ ! -s "$CERT" ]; then
  echo "❌ $CERT is missing"
  exit 1
fi
if [ ! -s "$F" ]; then
  echo "❌ $F is missing or empty"
  exit 1
fi

EXPECTED=$(openssl x509 -noout -enddate -in "$CERT" 2>/dev/null | sed 's/^notAfter=//')
if [ -z "$EXPECTED" ]; then
  echo "❌ Could not read the expiration date from $CERT"
  exit 1
fi

STUDENT=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^notAfter=//' "$F" | grep -v '^$' | head -1)
if [ -z "$STUDENT" ]; then
  echo "❌ $F does not contain a date"
  exit 1
fi

EXPECTED_EPOCH=$(date -u -d "$EXPECTED" +%s 2>/dev/null)
STUDENT_EPOCH=$(date -u -d "$STUDENT" +%s 2>/dev/null)

if [ -n "$EXPECTED_EPOCH" ] && [ -n "$STUDENT_EPOCH" ]; then
  if [ "$EXPECTED_EPOCH" != "$STUDENT_EPOCH" ]; then
    echo "❌ Expiration date is incorrect"
    echo "Found:    $STUDENT"
    echo "Expected: $EXPECTED"
    exit 1
  fi
else
  NORM_STUDENT=$(echo "$STUDENT" | tr -s ' ')
  NORM_EXPECTED=$(echo "$EXPECTED" | tr -s ' ')
  if [ "$NORM_STUDENT" != "$NORM_EXPECTED" ]; then
    echo "❌ Expiration date is incorrect"
    echo "Found:    $STUDENT"
    echo "Expected: $EXPECTED"
    exit 1
  fi
fi

echo "✅ Expiration date matches the kube-apiserver certificate: $EXPECTED"
exit 0
