#!/bin/bash

# Check if variables.tf already exists. If not, exit
if [ ! -f variables.tf ]; then 
    echo "variables.tf doesn't exist!"
    exit 1
fi

delete_script=`mktemp`
echo -n "`date` Checking kubernetes api..."
if timeout 10 kubectl get pod &>/dev/null; then 
    echo "OK! Removing loadbalancers..."
    kubectl get services -A | grep LoadBalancer | awk '{print "kubectl -n "$1" delete service "$2}' > ${delete_script}
    bash ${delete_script}
else
    echo "NOK! Continuing without remove loadbalancers!"
fi 


if tofu destroy --auto-approve; then 
    mv variables.tf variables.tf.removed
fi
