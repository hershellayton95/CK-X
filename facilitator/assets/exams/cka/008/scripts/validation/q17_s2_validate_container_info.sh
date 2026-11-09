#!/bin/bash
F=/tmp/exam/17/pod-container.txt
if [ ! -s "$F" ]; then
  echo "❌ /tmp/exam/17/pod-container.txt is missing or empty"
  exit 1
fi
CID_FULL=$(kubectl -n project-tiger get pod tigers-reunite -o jsonpath='{.status.containerStatuses[0].containerID}' 2>/dev/null)
CID=${CID_FULL#*://}
if [ -z "$CID" ]; then
  echo "❌ Could not determine the container ID from the Pod status"
  exit 1
fi
if ! grep -q "$CID" "$F"; then
  echo "❌ pod-container.txt does not contain the container ID $CID"
  exit 1
fi
if ! grep -qi 'containerd' "$F"; then
  echo "❌ pod-container.txt does not contain the containerd runtime type"
  exit 1
fi
echo "✅ pod-container.txt contains the container ID and containerd runtime"
exit 0
