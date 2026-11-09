#!/bin/bash
set -e
# Setup for Question 10: empty namespace for the RBAC exercise.
kubectl create namespace project-hamster --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "Setup completed for Question 10"
