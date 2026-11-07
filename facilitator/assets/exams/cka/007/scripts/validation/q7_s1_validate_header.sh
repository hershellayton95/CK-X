#!/bin/bash
F=/tmp/exam/outputs/admin2406_data
if [ ! -f "$F" ]; then
  echo "output file $F does not exist"
  exit 1
fi
HDR=$(head -1 "$F" | awk '{print $1" "$2" "$3" "$4}')
if [ "$HDR" != "DEPLOYMENT CONTAINER_IMAGE READY_REPLICAS NAMESPACE" ]; then
  echo "header is '$HDR', expected 'DEPLOYMENT CONTAINER_IMAGE READY_REPLICAS NAMESPACE'"
  exit 1
fi
echo "Header row is correct"
exit 0
