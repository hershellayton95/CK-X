#!/bin/bash
# Setup for Question 10: init container namespace
# (source: KodeKloud Practice Test - Init Containers)
kubectl create namespace init-ex --dry-run=client -o yaml | kubectl apply -f -
exit 0
