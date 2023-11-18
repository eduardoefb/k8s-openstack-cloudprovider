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
    if [ ${CREATE_HARBOR} -gt 0 ]; then        
        for (( i=0; i<${#registry_name[@]}; i++)); do
            echo ${registry_ext[i]} >> hosts 
            echo "  - name: ${registry_name[i]}" >> vars.yml
            echo "    ip: ${registry_int[i]}" >> vars.yml
        done
    else
        echo "  - name: registry.null.int" >> vars.yml
        echo "    ip: 0.0.0.0" >> vars.yml    
    fi

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
    echo "  os_identity_api_version: ${OS_IDENTITY_API_VERSION}" >> vars.yml
    echo "  os_image_api_version: ${OS_IMAGE_API_VERSION}" >> vars.yml
    echo "  os_project_domain_name: ${OS_PROJECT_DOMAIN_NAME}" >> vars.yml
    echo "  os_user_domain_name: ${OS_USER_DOMAIN_NAME}" >> vars.yml
    
    echo >> vars.yml
    echo "internal_subnet_id: `cat internal_subnet_id.txt`" >> vars.yml
    echo "floating_network_id: `cat floating_network_id.txt`" >> vars.yml

    if [ -f trusted_ca_list ]; then
        echo "trusted_ca_list:" >> vars.yml
        for ca in `cat trusted_ca_list`; do            
            echo "  - name: `openssl rand -hex 5`.crt" >> vars.yml
            echo "    src_file_name: ${ca}" >> vars.yml
        done
    else
        echo "trusted_ca_list: []" >> vars.yml
    fi
}

function usage(){
    echo "Usage:"
    echo "${0} --controller_nodes <x> --worker_nodes <y> [--no_harbor] [--no_istio]" 
    exit 1
}

export DOMAIN="k8so.int"
export LB_PREFIX="k8so-lb"

if [ -z "${1}" ]; then
    usage
fi 

export CREATE_HARBOR=1
export CREATE_ISTIO=1
echo $@
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --controller_nodes)
            MASTER_NODES="$2"
            shift
            ;;
        --worker_nodes)
            WORKER_NODES="$2"
            shift
            ;;
        --no_harbor) 
            export CREATE_HARBOR=0            
            ;;   
        --no_istio)            
            export CREATE_ISTIO=0            
            ;;                        
        *)
            usage
            exit 1
            ;;
    esac
    shift
done

# Check if variables exists. If yes, abort
if [ -f variables.tf ]; then 
    echo "Cluster already exists. Delete it first!"
    exit 1
fi

# Master nodes:
sed "s|#MASTER_NODES#|${MASTER_NODES}|g" variables.tf.template > variables.tf

# Worker nodes:
sed -i "s|#WORKER_NODES#|${WORKER_NODES}|g" variables.tf

# Registry:
if [ ${CREATE_HARBOR} -eq 1 ]; then 
    sed -i "s|#REGISTRY_NODES#|1|g" variables.tf
else
    sed -i "s|#REGISTRY_NODES#|0|g" variables.tf
fi

# NFS (for now, only 1):
sed -i "s|#NFS_NODES#|1|g" variables.tf

if [ ! -d ssh_keys ]; then
    mkdir -p ssh_keys
fi

if [ ! -f ssh_keys/id_rsa -o ! -f ssh_keys/id_rsa.pub ]; then
    ssh-keygen -t rsa -f ssh_keys/id_rsa -N ''
fi
# export TF_LOG=TRACE
if [ "${1}" == "-d" ]; then
    delete_script=`mktemp`
    kubectl get services -A | grep LoadBalancer | awk '{print "kubectl -n "$1" delete service "$2}' > ${delete_script}
    bash ${delete_script}
    terraform destroy --auto-approve
fi

terraform init || exit 1
terraform apply --auto-approve || exit 1


for f in *.txt; do echo >> $f; done
sed -i '/^$/d' *.txt

update_inventory

if [ ${CREATE_ISTIO} -eq 1 ]; then 
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts ansible-deploy.yml --extra-vars 'run_istio="yes"'
else
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts ansible-deploy.yml --extra-vars 'run_istio="no"'
fi

mkdir -p ~/.kube
cp files/kubeconfig ~/.kube/config
