#!/bin/bash
P=$(kubectl get deploy web -n drill-variation-b -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
PORT=$(kubectl get deploy web -n drill-variation-b -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null)
if [ -z "$P" ]; then
  echo "readinessProbe is no longer defined on Deployment web - the check must remain (only its path may change)"
  exit 1
fi
if [ "$P" != "/" ]; then
  echo "readinessProbe path is '$P', expected '/' (the path the app answers on)"
  exit 1
fi
if [ "$PORT" != "80" ]; then
  echo "readinessProbe port is '$PORT', expected 80"
  exit 1
fi
echo "readinessProbe kept and now checks path / on port 80"
exit 0
