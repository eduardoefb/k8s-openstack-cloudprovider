#### Deploy
- Create ssh keys:
```shell
mkdir ssh_keys
cd ssh_keys
ssh-keygen -t rsa -f id_rsa
cd ..
```

- Start the deployment
```shell
bash create.sh -d
```

### After deployment, do some tests:
- Connect to harbor virtual machine and check the admin password:
```shell
 grep admin /opt/harbor/harbor.yml 
 ```

 Create a regular user and a project, than, connect go the bastian and create a test image:


- Create a sample image
```bash

rm -rf ~/tmpimage
mkdir ~/tmpimage
cd ~/tmpimage
cat << EOF > run.sh
#!/bin/bash
cd /tmp/
echo "It works. Hostname: \${HOSTNAME}" > /tmp/input.txt
python3 -m http.server
EOF

cat << EOF >> Dockerfile
FROM ubuntu:20.04
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install python3 iproute2 curl net-tools
RUN groupadd appuser -g 1000750000
RUN useradd --no-log-init -m appuser -u 1000750000 -g 1000750000
COPY run.sh /opt/run.sh
RUN chmod 755 /opt/run.sh
CMD [ "/opt/run.sh" ]
EOF

buildah bud -f Dockerfile -t testimage:0.0.3

```

- Login to registry:
```shell
podman login https://registry.kube.int
```

- Tag and upload the image
```shell
podman tag localhost/testimage:0.0.3 registry.kube.int/k8s/testimage:0.0.3
podman push registry.kube.int/k8s/testimage:0.0.3
```

- Create a credentials config
```shell
REGISTRY_HOSTNAME="registry.kube.int"
echo "Enter your registry username:"
read reg_user
echo "Enter your registry pass:"
read -s reg_pass

REGISTRY_CREDENTIALS="eduardoefb:Mirunda12#"
cat << EOF > /tmp/secret.json
{
   "auths": {
      "${REGISTRY_HOSTNAME}": {
         "auth": "`echo -n "${reg_user}:${reg_pass}" | base64`"
      }
   }
}
EOF
```

- Create a test namespace and make it default
```shell
kubectl create namespace test
kubectl config set-context --current --namespace=test
```

- Create the registry secret
```shell
kubectl delete secret registry-auth
kubectl create secret generic registry-auth \
    --from-file=.dockerconfigjson=/tmp/secret.json \
    --type=kubernetes.io/dockerconfigjson
kubectl get secret registry-auth
```

- Create the test deployment:
```bash
kubectl delete pod test-pod
image="registry.kube.int/k8s/testimage:0.0.3"
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:

  namespace: test
  name: test-pod
  labels:
    app: test-pod
spec:
  imagePullSecrets:
  - name: registry-auth
  containers:
  - name: netshoot-pod
    image: ${image}
    imagePullPolicy: Always 
    ports:
    - containerPort: 8000
    securityContext:
      runAsUser: 1000750000
      runAsGroup: 1000750000     
  terminationGracePeriodSeconds: 0
 
EOF


kubectl delete deployment test-deployment
cat << EOF | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  labels:
    app: test-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test-deployment
  template:
    metadata:
      labels:
        app: test-deployment
    spec:
      imagePullSecrets:
      - name: registry-auth    
      containers:
      - name: test-deployment
        image: ${image}
        securityContext:
          runAsUser: 1000750000
          runAsGroup: 1000750000           
        ports:
        - containerPort: 8000
EOF


```

- Expose the testpod 
```shell
kubectl expose deployment test-deployment --type LoadBalancer --name test-deployment-external
```

- Wait until the service is available and test:
```shell
ipaddr=`kubectl get service test-deployment-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
curl http://${ipaddr}:8000/input.txt
```

Expected output
```log
debian@k8s-bastian:~/tmpimage$ curl http://${ipaddr}:8000/input.txt
It works. Hostname: test-deployment-55b557fc7c-m4cpm
debian@k8s-bastian:~/tmpimage$ 
```

#### Istio

Allow namespace to get istio injected:
```shell
kubectl label namespace test istio-injection=enabled
kubectl scale deployment test-deployment --replicas=0
kubectl scale deployment test-deployment --replicas=2

```