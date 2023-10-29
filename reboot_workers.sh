#!/bin/bash

# Check if variables.tf already exists. If not, exit
if [ ! -f variables.tf ]; then 
    echo "variables.tf doesn't exist!"
    exit 1
fi

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts reboot-workers.yml
