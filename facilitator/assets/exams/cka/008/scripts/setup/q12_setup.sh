#!/bin/bash
set -e
# Setup for Question 12: shared namespace for the scheduling exercise.
kubectl create namespace project-tiger --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "Setup completed for Question 12"
