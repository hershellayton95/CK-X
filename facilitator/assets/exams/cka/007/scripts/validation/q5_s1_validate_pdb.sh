#!/bin/bash
J=$(kubectl get pdb critical-db-pdb -n maintenance -o json 2>/dev/null) || { echo "PodDisruptionBudget critical-db-pdb not found in maintenance"; exit 1; }
MA=$(echo "$J" | jq -r '.spec.minAvailable // "missing"')
if [ "$MA" != "2" ]; then
  echo "minAvailable is '$MA', expected 2"
  exit 1
fi
SEL=$(echo "$J" | jq -r '.spec.selector.matchLabels.app // "missing"')
if [ "$SEL" != "critical-db" ]; then
  echo "PDB selector matches app='$SEL', expected critical-db"
  exit 1
fi
echo "PDB critical-db-pdb exists with minAvailable 2 selecting critical-db pods"
exit 0
