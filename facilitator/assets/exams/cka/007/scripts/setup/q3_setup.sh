#!/bin/bash
# Setup for Question 3: DaemonSet creation namespace
# (source: KodeKloud Practice Test - DaemonSets)
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
exit 0
