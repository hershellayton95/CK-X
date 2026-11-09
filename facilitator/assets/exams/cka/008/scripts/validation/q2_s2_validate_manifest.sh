#!/bin/bash
F=/tmp/exam/2/cluster-issuer.yaml
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/2/cluster-issuer.yaml is missing or empty"
  exit 1
fi
if ! grep -Eq 'crlDistributionPoints' "$F"; then
  echo "❌ The manifest does not contain crlDistributionPoints"
  exit 1
fi
if ! grep -Eq 'http://example\.com/crl' "$F"; then
  echo "❌ The manifest does not contain http://example.com/crl"
  exit 1
fi
echo "✅ The manifest contains the requested CRL distribution point"
exit 0
