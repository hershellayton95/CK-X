#!/bin/bash
F=/tmp/exam/17/pod-container.log
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/17/pod-container.log is missing or empty"
  exit 1
fi
if ! grep -Eqi 'apache|ah00|httpd' "$F"; then
  echo "❌ pod-container.log does not contain the httpd container logs"
  exit 1
fi
echo "✅ pod-container.log contains the httpd container logs"
exit 0
