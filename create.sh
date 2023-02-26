#!/bin/bash
function update_inventory(){
    cat /dev/null > hosts
    cat /dev/null > vars.yml
    unset bastian_name
    unset bastian_int 
    unset bastian_ext    
    unset master_name
    unset master_int
    unset master_ext
    unset worker_name
    unset worker_int
    unset worker_ext
    unset nfs_name
    unset nfs_int
    unset nfs_ext
    unset registry_name
    unset registry_int
    unset registry_ext

    bastian_id=`cat bastian.txt | head -1 | awk '{print $1}'`
    addr_line=`openstack server show ${bastian_id} -f value -c addresses`
    bastian_int=$(awk -F \' '{print $4}' <<< ${addr_line})
    bastian_ext=$(awk -F \' '{print $6}' <<< ${addr_line})

    while read l; do
        if [ ! -z "${l}" ]; then
            i_id=$(awk '{print $1}' <<< ${l})
            master_name+=($(awk '{print $2}' <<< ${l}))
            addr_line=`openstack server show ${i_id} -f value -c addresses`
            master_int+=($(awk -F \' '{print $4}' <<< ${addr_line}))
            master_ext+=($(awk -F \' '{print $6}' <<< ${addr_line}))
        fi
    done <master.txt

    while read l; do
        if [ ! -z "${l}" ]; then
            i_id=$(awk '{print $1}' <<< ${l})
            worker_name+=($(awk '{print $2}' <<< ${l}))
            addr_line=`openstack server show ${i_id} -f value -c addresses`
            worker_int+=($(awk -F \' '{print $4}' <<< ${addr_line}))
            worker_ext+=($(awk -F \' '{print $6}' <<< ${addr_line}))
        fi
    done <worker.txt

    while read l; do
        if [ ! -z "${l}" ]; then    
            i_id=$(awk '{print $1}' <<< ${l})
            nfs_name+=($(awk '{print $2}' <<< ${l}))
            addr_line=`openstack server show ${i_id} -f value -c addresses`
            nfs_int+=($(awk -F \' '{print $4}' <<< ${addr_line}))
            nfs_ext+=($(awk -F \' '{print $6}' <<< ${addr_line}))
        fi
    done <nfs.txt

    while read l; do
        if [ ! -z "${l}" ]; then    
            i_id=$(awk '{print $1}' <<< ${l})
            registry_name+=($(awk '{print $2}' <<< ${l}))
            addr_line=`openstack server show ${i_id} -f value -c addresses`
            registry_int+=($(awk -F \' '{print $4}' <<< ${addr_line}))
            registry_ext+=($(awk -F \' '{print $6}' <<< ${addr_line}))
        fi
    done <registry.txt


    echo "[BASTIAN]" >> hosts    
    echo "${bastian_ext}" >> hosts
    echo >> hosts 

    echo "[MASTER]" >> hosts
    echo "master:" >> vars.yml
    for (( i=0; i<${#master_name[@]}; i++)); do
        echo ${master_ext[i]} >> hosts 
        echo "  - name: ${master_name[i]}" >> vars.yml
        echo "    ip: ${master_int[i]}" >> vars.yml
    done
    echo >> vars.yml
    echo >> hosts
    echo "[WORKER]" >> hosts
    echo "worker:" >> vars.yml
    for (( i=0; i<${#worker_name[@]}; i++)); do
        echo ${worker_ext[i]} >> hosts 
        echo "  - name: ${worker_name[i]}" >> vars.yml
        echo "    ip: ${worker_int[i]}" >> vars.yml
    done
    echo >> vars.yml
    echo >> hosts
    echo "[NFS]" >> hosts
    echo "nfs:" >> vars.yml
    for (( i=0; i<${#nfs_name[@]}; i++)); do
        echo ${nfs_ext[i]} >> hosts 
        echo "  - name: ${nfs_name[i]}" >> vars.yml
        echo "    ip: ${nfs_int[i]}" >> vars.yml
    done
    echo >> vars.yml
    echo >> hosts
    echo "[REGISTRY]" >> hosts
    echo "registry:" >> vars.yml
    for (( i=0; i<${#registry_name[@]}; i++)); do
        echo ${registry_ext[i]} >> hosts 
        echo "  - name: ${registry_name[i]}" >> vars.yml
        echo "    ip: ${registry_int[i]}" >> vars.yml
    done
    echo >> vars.yml
    echo >> hosts
    echo "[ALL]" >> hosts 
    echo "all:" >> vars.yml
    echo ${bastian_ext} >> hosts
    for (( i=0; i<${#master_name[@]}; i++)); do
        echo ${master_ext[i]} >> hosts 
        echo "  - name: ${master_name[i]}" >> vars.yml
        echo "    ip: ${master_int[i]}" >> vars.yml
    done

    for (( i=0; i<${#worker_name[@]}; i++)); do
        echo ${worker_ext[i]} >> hosts 
        echo "  - name: ${worker_name[i]}" >> vars.yml
        echo "    ip: ${worker_int[i]}" >> vars.yml
    done

    for (( i=0; i<${#nfs_name[@]}; i++)); do
        echo ${nfs_ext[i]} >> hosts 
        echo "  - name: ${nfs_name[i]}" >> vars.yml
        echo "    ip: ${nfs_int[i]}" >> vars.yml
    done

    for (( i=0; i<${#registry_name[@]}; i++)); do
        echo ${registry_ext[i]} >> hosts 
        echo "  - name: ${registry_name[i]}" >> vars.yml
        echo "    ip: ${registry_int[i]}" >> vars.yml
    done    
    echo >> vars.yml
    echo "all_external:" >> vars.yml
    for (( i=0; i<${#master_name[@]}; i++)); do
        echo "  - ${master_ext[i]}" >> vars.yml
    done

    for (( i=0; i<${#worker_name[@]}; i++)); do 
        echo "  - ${worker_ext[i]}" >> vars.yml
    done

    for (( i=0; i<${#nfs_name[@]}; i++)); do
        echo "  - ${nfs_ext[i]}" >> vars.yml
    done

    for (( i=0; i<${#registry_name[@]}; i++)); do
        echo "  - ${registry_ext[i]}" >> vars.yml
    done  
    echo "  - ${bastian_ext}" >> vars.yml

    echo >> vars.yml
    echo "int_net: `cat int_network.txt`" >> vars.yml
    echo "domain: `cat domain.txt | sed 's/.$//g'`" >> vars.yml
    echo "registry_fqdn: registry.`cat domain.txt | sed 's/.$//g'`"  >> vars.yml
    echo "nfs_fqdn: nfs.`cat domain.txt | sed 's/.$//g'`"  >> vars.yml
    echo "c: C=BR"  >> vars.yml

    echo >> hosts
    echo "[all:vars]" >> hosts 
    echo "ansible_ssh_private_key_file=ssh_keys/id_rsa" >> hosts
    echo >> hosts  
    echo >> vars.yml
    echo "dns_nameservers:" >> vars.yml
    for i in `cat dns.txt`; do
        echo "  - ${i}" >> vars.yml
    done
    echo >> vars.yml
    echo "lb_vip_address: `cat lb_vip_address.txt`" >> vars.yml
    echo >> vars.yml

    echo "openstack:" >> vars.yml
    echo "  auth_url: ${OS_AUTH_URL}" >> vars.yml
    echo "  cacert: ${OS_CACERT}" >> vars.yml
    echo "  username: ${OS_USERNAME}" >> vars.yml
    echo "  password: ${OS_PASSWORD}" >> vars.yml
    echo "  project_name: ${OS_PROJECT_NAME}" >> vars.yml
    echo "  domain_name: ${OS_USER_DOMAIN_NAME}" >> vars.yml
    echo "  project_id: `openstack project show ${OS_PROJECT_NAME} -f value -c id`"  >> vars.yml
    echo "  region: `openstack region list -f value -c Region | head -1`" >> vars.yml
    
    echo >> vars.yml
    echo "internal_subnet_id: `cat internal_subnet_id.txt`" >> vars.yml
    echo "floating_network_id: `cat floating_network_id.txt`" >> vars.yml
}


export DOMAIN="k8so.int"
export LB_PREFIX="k8so-lb"

if [ ! -d ssh_keys ]; then
    mkdir -p ssh_keys
fi

if [ ! -f ssh_keys/id_rsa -o ! -f ssh_keys/id_rsa.pub ]; then
    ssh-keygen -t rsa -f ssh_keys/id_rsa -N ''
fi

if [ "${1}" == "-d" ]; then
  terraform destroy --auto-approve
fi
terraform apply --auto-approve
for f in *.txt; do echo >> $f; done
sed -i '/^$/d' *.txt

update_inventory

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts ansible-deploy.yml

mkdir -p ~/.kube
cp files/kubeconfig ~/.kube/config
