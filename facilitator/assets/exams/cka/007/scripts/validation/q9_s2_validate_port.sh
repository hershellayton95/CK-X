#!/bin/bash
P=$(kubectl get netpol cyan-np -n cyan-ns -o json 2>/dev/null | jq -r '[.spec.ingress[]?.ports[]?.port | tostring] | join(",")')
case ",$P," in
  *,80,*) ;;
  *) echo "ingress ports are '$P', expected 80 (the nginx app listens on 80)"; exit 1;;
esac
echo "Ingress rule allows port 80"
exit 0
