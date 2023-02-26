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