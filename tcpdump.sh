#!/bin/bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts tcpdump.yml
cd pcap
mergecap *.pcap -w all.pcap
