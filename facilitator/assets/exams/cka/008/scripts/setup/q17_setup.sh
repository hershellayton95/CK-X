#!/bin/bash
set -e
# Setup for Question 17: clean scratch space; the student creates the Pod.
kubectl create namespace project-tiger --dry-run=client -o yaml | kubectl apply -f - >/dev/null
mkdir -p /tmp/exam/17
kubectl -n project-tiger delete pod tigers-reunite --ignore-not-found >/dev/null 2>&1 || true
echo "Setup completed for Question 17"
