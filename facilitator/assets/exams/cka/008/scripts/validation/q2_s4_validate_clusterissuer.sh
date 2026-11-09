#!/bin/bash
if ! kubectl get clusterissuer course-issuer >/dev/null 2>&1; then
  echo "❌ ClusterIssuer course-issuer does not exist"
  exit 1
fi
CRL=$(kubectl get clusterissuer course-issuer -o jsonpath='{.spec.selfSigned.crlDistributionPoints[0]}' 2>/dev/null)
if [ "$CRL" != "http://example.com/crl" ]; then
  echo "❌ ClusterIssuer course-issuer has CRL distribution point '${CRL:-none}', expected http://example.com/crl"
  exit 1
fi
echo "✅ ClusterIssuer course-issuer has the requested CRL distribution point"
exit 0
