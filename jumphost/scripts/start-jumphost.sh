#!/bin/bash
# Jumphost container entrypoint.
#
# SSH sessions do not inherit the container environment, so persist the values
# the exam scripts need into /etc/ckx-env. prepare-exam-env/cleanup-exam-env
# source that file in every SSH session. %q keeps tokens with shell
# metacharacters safe.
set -u

{
  printf 'CLUSTER_NAME=%q\n' "${CLUSTER_NAME:-cluster}"
  printf 'FACILITATOR_URL=%q\n' "${FACILITATOR_URL:-http://facilitator:3000}"
  printf 'INTERNAL_TOKEN=%q\n' "${INTERNAL_TOKEN:-}"
} > /etc/ckx-env
chmod 600 /etc/ckx-env

service ssh start && dockerd &
tail -f /dev/null
