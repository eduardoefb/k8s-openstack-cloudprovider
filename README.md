
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
bash create.sh --controller_nodes <x> --worker_nodes <y> [--no_harbor]
```
Note: Use the option `--no_harbor` if you don't want to deploy the image/helm registry

#### Scale
To scale, execute the `scale.sh` script by informing the new number of worker nodes:
```shell
bash scale.sh <number of worker nodes>
```

#### Replace a worker node:
To replace a worker node, delete the worker node from the kubernetes cluster (example for worker-0):
```shell
kubectl drain --ignore-daemonsets --delete-emptydir-data <prefix>-worker-0
kubectl delete node <prefix>-worker-0
```
And than, redeploy the worker node using terraform apply --replace command (example for worker-0):
```shell
terraform apply --replace openstack_compute_instance_v2.worker[0]
```

And last, execute the scale script with the current number of desired worker nodes:
```shell
bash scale.sh <number of worker nodes>
```

### After deployment, do some tests:
The Harbor administrator password is located in the 'files/harbor.yml' file, which is created when the Harbor deployment is completed. The administrator password is required to add new users and projects. Alternatively, there is a Python script that uses Selenium to create new users:

```shell
 python3 add_harbor_user_project.py
 ```

With user and project, you can start the test:

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

REGISTRY_CREDENTIALS="${reg_user}:${reg_pass}"
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
image="registry.kube.int/k8s/testimage:0.0.3"
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
kubectl rollout restart deployment test-deployment

```

Create the services:
```shell
kubectl expose deployment test-deployment --port 80 --target-port 8000
```

Create the gateway and virtualservice:
```shell
cat << EOF | kubectl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: test-gateway
spec:
  selector:
    istio: ingressgateway 
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: testvs
spec:
  hosts:
  - "*"
  gateways:
  - test-gateway
  http:
  - match:
    - uri:
        exact: /input.txt        
    route:
    - destination:
        host: test-deployment
        port:
          number: 80
EOF
```


Check:
```
ingress_gw_ip=`kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
curl http://${ingress_gw_ip}/input.txt

```


## Customizations in jaeger tracing:
https://istio.io/latest/docs/tasks/observability/distributed-tracing/mesh-and-proxy-config/#customizing-trace-sampling