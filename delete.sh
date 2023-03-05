#!/bin/bash
delete_script=`mktemp`
kubectl get services -A | grep LoadBalancer | awk '{print "kubectl -n "$1" delete service "$2}' > ${delete_script}
bash ${delete_script}
terraform destroy --auto-approve