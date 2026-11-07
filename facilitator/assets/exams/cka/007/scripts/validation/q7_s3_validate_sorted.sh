#!/bin/bash
F=/tmp/exam/outputs/admin2406_data
if [ ! -f "$F" ]; then
  echo "output file $F does not exist"
  exit 1
fi
tail -n +2 "$F" | awk 'NF{print $1}' > /tmp/exam/.q7_names
if ! sort -c /tmp/exam/.q7_names 2>/dev/null; then
  echo "rows are not sorted by deployment name ascending: $(tr '\n' ' ' < /tmp/exam/.q7_names)"
  exit 1
fi
N=$(grep -c . /tmp/exam/.q7_names)
if [ "$N" -lt 2 ]; then
  echo "expected at least 2 deployment rows, found $N"
  exit 1
fi
echo "Rows sorted by deployment name ascending"
exit 0
