#!/bin/bash
for p in `openstack loadbalancer pool list | grep ACT | awk '{print $2}'`; do
  for m in `openstack loadbalancer member list $p | grep ACT | awk '{print $2}'`; do 
    openstack loadbalancer member delete $p $m
  done
  openstack loadbalancer pool delete $p
done

for p in `openstack loadbalancer listener list | grep True | awk '{print $2}'`; do
  openstack loadbalancer listener delete $p
done

for p in `openstack loadbalancer list | grep ACT | awk '{print $2}'`; do
  openstack loadbalancer delete $p
done
