# About

You can learn more about this project from the following articles.

* https://venilnoronha.io/seamless-cloud-native-apps-with-grpc-web-and-istio
* https://blogs.vmware.com/opensource/2019/04/16/implementing-grpc-web-istio-envoy/

You can learn more about protobuf
* https://developers.google.com/protocol-buffers/docs/proto3#reserved
* https://developers.google.com/protocol-buffers/docs/reference/cpp-generated#arena

## Optional

Install grpc-web browser plugin `https://chrome.google.com/webstore/detail/grpc-web-developer-tools/ddamlpimmiapbcopeoifjfmoabdbfbjj`

## Guide

Install `VirtualBox` https://gist.github.com/blockspacer/0237dcdea981f78f8c3ea80b8b1d037d#install-virtualbox

Install `docker` https://gist.github.com/blockspacer/0237dcdea981f78f8c3ea80b8b1d037d#install-docker

Install conan artifactory https://gist.github.com/blockspacer/211a932cb0a535a1b098ec0ac562eeb8#gistcomment-3147793

Install `minikube` https://gist.github.com/blockspacer/0237dcdea981f78f8c3ea80b8b1d037d#install-minikube

Install istio https://gist.github.com/blockspacer/0237dcdea981f78f8c3ea80b8b1d037d#install-istio

For istio on minikube follow https://istio.io/docs/setup/platform-setup/minikube/

Add istioctl to PATH https://gist.github.com/blockspacer/0237dcdea981f78f8c3ea80b8b1d037d#add-istioctl-to-path

Enable `registry` addon for `minikube` as in https://minikube.sigs.k8s.io/docs/tasks/docker_registry/

Generate TLS certs and apply as kubectl secret, see below

```bash
kubectl exec -it -n istio-system $(kubectl -n istio-system get pods -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}') -- ls -al /etc/istio/ingressgateway-certs
```

Must print

```bash
# ...
lrwxrwxrwx 1 root root   14 Feb 28 10:30 tls.crt -> ..data/tls.crt
lrwxrwxrwx 1 root root   14 Feb 28 10:30 tls.key -> ..data/tls.key
# ...
```

Tested with `GRPC_RELEASE_TAG=v1.26.x`

We can now simply deploy the above configurations in the following order.

Note that once we deploy this service over Istio, the grpc- prefix in the Service port name will allow Istio to recognize this as a gRPC service.

Build and push deps to local conan package registry as in `cat scripts/clean_start.sh`

```bash
minikube stop
# OR minikube delete
# Use `--insecure-registry='192.168.39.0/24'`, see https://minikube.sigs.k8s.io/docs/tasks/docker_registry/
minikube start --alsologtostderr --kubernetes-version v1.13.0 --memory=14288 --cpus=4 --disk-size 30GB --vm-driver virtualbox \
  --extra-config='apiserver.enable-admission-plugins=LimitRanger,NamespaceExists,NamespaceLifecycle,ResourceQuota,ServiceAccount,DefaultStorageClass,MutatingAdmissionWebhook' \
  --extra-config=apiserver.authorization-mode=RBAC \
  --insecure-registry='localhost' \
  --insecure-registry='127.0.0.1' \
  --insecure-registry "192.168.39.0/24"
# OPTIONAL: open dashboard
minikube addons enable dashboard && kubectl get pods --all-namespaces | grep dashboard && sleep 15 && minikube dashboard --url
# see http://rastko.tech/kubernetes/2019/01/01/minikube-on-mac.html
minikube addons enable ingress
# It will take few mins for the registry to be enabled, you can watch the status using kubectl get pods -n kube-system -w | grep registry
# Use `--insecure-registry='192.168.39.0/24'`, see https://minikube.sigs.k8s.io/docs/tasks/docker_registry/
minikube addons enable registry
# check the CLUSTER-IP of the registry service using the command
# Wait for the Daemonset to be running!!!
kubectl -n kube-system get svc registry -o jsonpath='{.spec.clusterIP}'
# see https://minikube.sigs.k8s.io/docs/tasks/registry/insecure/
# see http://rastko.tech/kubernetes/2019/01/01/minikube-on-mac.html
# see http://rastko.tech/kubernetes/2019/01/01/minikube-on-mac.html
# see http://rastko.tech/kubernetes/2019/01/01/minikube-on-mac.html

(OPTIONAL) Now the kubernetes part. Copy the clusterIP of the registry service running on kube-system namespace and put it on the pod spec's image as in https://amritbera.com/journal/minikube-insecure-registry.html:

```yaml
...
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: my-container
        # <cluster-ip> from kubectl -n kube-system get svc registry -o jsonpath='{.spec.clusterIP}'
        # replace 80 with port number (5000)
        image: <cluster-ip>:80/my-image:1
...
```

(OPTIONAL) Add result of `echo $(minikube ip)` into `NO_PROXY` in `/etc/systemd/system/docker.service.d/http-proxy.conf` or `~/.docker/config.json`

Use minikube context:

```bash
kubectl config use-context minikube
```

(OPTIONAL) configure dns in minikube

```bash
minikube ssh -- sudo mkdir -p /etc/docker
minikube ssh -- sudo touch /etc/docker/daemon.json
# NOTE: can't set "insecure-registries" due to `--insecure-registry` minikube arg
# add dns from /etc/resolv.conf into /etc/docker/daemon.json
# also add dns (IP4.DNS[1]) from `nmcli dev show | grep 'IP4.DNS'` as in https://development.robinwinslow.uk/2016/06/23/fix-docker-networking-dns/
cat <<EOF | minikube ssh sudo tee /etc/docker/daemon.json
{
    "dns": ["127.0.0.53", "8.8.4.4", "8.8.8.8"],
    "registry-mirrors":["https://docker.mirrors.ustc.edu.cn"],
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "50m",
      "max-file": "3"
    }
}
EOF
minikube ssh -- sudo cat /etc/docker/daemon.json
minikube ssh -- sudo systemctl daemon-reload
minikube ssh -- sudo systemctl restart docker
```

(OPTIONAL) use minikube tunnel feature

```bash
# Run this command in a different terminal, because the minikube tunnel feature will block your terminal to output diagnostic information about the network:
minikube tunnel
# Sometimes minikube does not clean up the tunnel network properly. To force a proper cleanup:
minikube tunnel --cleanup
```

Apply istio manifest:

```bash
# (OPTIONAL) delete old istio instance
# https://github.com/istio/istio/issues/6085#issuecomment-493015039
#(kubectl delete meshpolicy default || true)
(kubectl delete ns istio-system || true)

istioctl verify-install

# create new istio instance
istioctl manifest apply --skip-confirmation
# OR
# istioctl manifest apply --set values.global.mtls.enabled=true,values.security.selfSigned=false --set values.global.controlPlaneSecurityEnabled=true

# Enable automatic sidecar injection for defaultnamespace
(kubectl label namespace default istio-injection=enabled || true)
```

Apply TLS Certs to istio namespace, see below

## Build docker images

```bash
# mkdir -p ~/net/authservice
# cd ~/net/authservice
# git clone https://github.com/istio-ecosystem/authservice.git --recursive .
# #make docker-from-scratch
# sudo -E docker build -f build/Dockerfile.builder -t gaeus:authservice .
# sudo -E docker tag gaeus:authservice $(minikube ip):5000/gaeus:authservice
# cd -

# NOTE: create GITHUB_TOKEN with `read:packages` scope as in https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line
# NOTE: GITHUB_TOKEN from https://github.com/settings/tokens
sudo -E docker login -u USER_NAME -p GITHUB_TOKEN docker.pkg.github.com
#export AUTHSERVICE_IMAGE=authservice
export AUTHSERVICE_IMAGE=docker.pkg.github.com/istio-ecosystem/authservice/authservice:0.1.0-243af67fc9eb
sudo -E docker pull $AUTHSERVICE_IMAGE --disable-content-trust
# push image
sudo -E docker tag $AUTHSERVICE_IMAGE $(minikube ip):5000/gaeus:authservice
sudo -E docker push $(minikube ip):5000/gaeus:authservice

sudo -E docker build \
  --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* \
  -f docker/cxx_build_env.Dockerfile \
  --tag gaeus:cxx_build_env . \
  --no-cache

sudo -E docker tag gaeus:cxx_build_env $(minikube ip):5000/gaeus:cxx_build_env

# grpc_build_env is OPTIONAL
# NOTE: you can place already cloned grpc into `GRPC_LOCAL_TO_PROJECT_PATH` and enable `BUILD_GRPC_FROM_SOURCES`
# sudo -E docker build --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* --build-arg GRPC_LOCAL_TO_PROJECT_PATH=grpc --build-arg BUILD_GRPC_FROM_SOURCES=False --build-arg BUILD_GRPC_WEB_FROM_SOURCES=False -f docker/grpc_build_env.Dockerfile --tag $(minikube ip):5000/gaeus:grpc_build_env . --no-cache

export MY_IP=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')

sudo -E docker build \
  --build-arg BUILD_TYPE=Release \
  --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* \
  --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
  --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
  -f docker/web-ui.Dockerfile \
  --tag gaeus:web-ui . \
  --no-cache

sudo -E docker tag gaeus:web-ui $(minikube ip):5000/gaeus:web-ui

# TODO: INSTALL_GRPC_FROM_CONAN
# NOTE: --build-arg BUILD_TYPE=Release
# NOTE: to add custom conan repo replace YOUR_REPO_URL_HERE in: --build-arg CONAN_EXTRA_REPOS="conan-local http://YOUR_REPO_URL_HERE:8081/artifactory/api/conan/conan False" --build-arg CONAN_EXTRA_REPOS_USER="user -p password -r conan-local admin"
sudo -E docker build \
  --build-arg BUILD_TYPE=Release \
  --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* \
  --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
  --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
  -f docker/server.Dockerfile \
  --tag gaeus:server . \
  --no-cache

sudo -E docker tag gaeus:server $(minikube ip):5000/gaeus:server
```

## Push docker images to local minikube

If you want to use `minikube addons enable registry`, see `https://minikube.sigs.k8s.io/docs/tasks/docker_registry/`

Yo may want to add output of `echo $(minikube ip)` and `echo $(minikube ip):5000` into `"insecure-registries"` in `/etc/docker/daemon.json`

```bash
# Ensure that docker is configured to use 192.168.39.0/24 as insecure registry
# see https://minikube.sigs.k8s.io/docs/tasks/docker_registry/
sudo -E cp /etc/docker/daemon.json /etc/docker/daemon.json.backup # backup
sudo -E touch /etc/docker/daemon.json
sudo -E cat <<EOF | sudo -E tee /etc/docker/daemon.json
{
    "dns": ["127.0.0.53", "8.8.4.4", "8.8.8.8"],
    "insecure-registries": [
      "192.168.39.0/24",
      "$(minikube ip):5000"
    ],
    "registry-mirrors":["https://docker.mirrors.ustc.edu.cn"],
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "50m",
      "max-file": "3"
    }
}
EOF
sudo -E cat /etc/docker/daemon.json

# reload docker after changes in in `/etc/docker/daemon.json`
sudo systemctl daemon-reload
sudo systemctl restart docker
```

```bash
sudo -E docker push $(minikube ip):5000/gaeus:server

sudo -E docker push $(minikube ip):5000/gaeus:web-ui

sudo -E docker push $(minikube ip):5000/gaeus:authservice

# cxx_build_env is OPTIONAL
# sudo -E docker push $(minikube ip):5000/gaeus:cxx_build_env

# grpc_build_env is OPTIONAL
# sudo -E docker push $(minikube ip):5000/gaeus:grpc_build_env

# Check repositories catalog
http_proxy= no_proxy="$(minikube ip),localhost" \
  curl -vk http://$(minikube ip):5000/v2/_catalog

# Check tags in repository
http_proxy= no_proxy="$(minikube ip),localhost" \
  curl -vk http://$(minikube ip):5000/v2/gaeus/tags/list
```

## Keycloak

TODO!!!!
deploy keycloak
see https://gist.github.com/blockspacer/211a932cb0a535a1b098ec0ac562eeb8#gistcomment-3147793

## TLS Certs

Delete old app

```bash
cd -

bash clean.sh

kubectl get all -n default
kubectl get ingress -n default
kubectl get gateway -n default
kubectl get destinationrules -n default
kubectl get virtualservices -n default
kubectl get pod -n default

# CAUTION!
# kubectl delete namespaces default --grace-period=5 --force
```

Crete new certs

```bash
cd tools/gen_cert
sh ./dockerized_gen_cert.sh
sudo chown $USER *.key *.csr *.crt
chmod 400 *.key
file httpbin.example.com.key
file httpbin.example.com.crt
# see https://istio.io/docs/tasks/traffic-management/ingress/secure-ingress-mount/
# The secret must be named istio-ingressgateway-certs in the istio-system namespace to align with the configuration of the Istio default ingress gateway used in this task.
kubectl delete --ignore-not-found=true -n istio-system secret istio-ingressgateway-certs istio-ingressgateway-ca-certs
sleep 5 # wait
kubectl create -n istio-system secret tls istio-ingressgateway-certs --key httpbin.example.com.key --cert httpbin.example.com.crt
sleep 5 # wait
# Verify that tls.crt and tls.key have been mounted in the ingress gateway pod:
kubectl exec -it -n istio-system $(kubectl -n istio-system get pods -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}') -- ls -al /etc/istio/ingressgateway-certs
```

Must print

```bash
# ...
lrwxrwxrwx 1 root root   14 Feb 28 10:30 tls.crt -> ..data/tls.crt
lrwxrwxrwx 1 root root   14 Feb 28 10:30 tls.key -> ..data/tls.key
# ...
```

```bash
# ... Re-deploy app ... AS ABOVE ...
bash deploy.sh
```

```bash
# CHECK
kubectl get componentstatuses
```

It might take time for the gateway definition to propagate so you might get the following error: `Failed to connect to httpbin.example.com port <your secure port>: Connection refused.` Wait for a minute and then retry the curl call.

```bash
cd tools/gen_cert
echo "INGRESS_HOST=$INGRESS_HOST INGRESS_PORT=$INGRESS_PORT SECURE_INGRESS_PORT=$SECURE_INGRESS_PORT"
curl -v -HHost:httpbin.example.com --resolve httpbin.example.com:$SECURE_INGRESS_PORT:$INGRESS_HOST --cacert httpbin.example.com.crt https://$INGRESS_HOST:$SECURE_INGRESS_PORT/status/418
# Validate `Server certificate:` in output
cd -
```

Don't forget to add it to Chromium browser `Chromium -> Setting -> (Advanced) Manage Certificates -> Import -> 'server_rootCA.pem'`

## Upload yaml files

```bash
cd istio

# Tag your images with $(minikube ip):5000/image-name and push them.
# Inside k8s your images will be available from localhost:5000 registry, so your k8s manifests should specify image as `localhost:5000/image-name`.
export REGISTRY_IP=localhost # Requires pushing of images to registry
#export REGISTRY_IP=$(minikube ip) # Requires `eval $(minikube docker-env)`
export REGISTRY_PORT=5000

# use $INGRESS_HOST:$INGRESS_PORT from https://istio.io/docs/tasks/traffic-management/ingress/ingress-control/
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export INGRESS_HOST=$(minikube ip)
echo "INGRESS_HOST=$INGRESS_HOST INGRESS_PORT=$INGRESS_PORT SECURE_INGRESS_PORT=$SECURE_INGRESS_PORT"

bash deploy.sh

# NOTE: waits by pod label, see -lapp=...
kubectl wait pod -lapp=web-ui --for=condition=Ready --timeout=30s -n default
kubectl get pods | grep -m2 "web-ui-"
kubectl get svc web-ui

# check `minikube service ...... --url` via curl
http_proxy= no_proxy="$(minikube ip),$(minikube service web-ui --url),localhost" \
  curl -vk $(minikube service web-ui --url)

# NOTE: waits by pod label, see -lapp=...
kubectl wait pod -lapp=server --for=condition=Ready --timeout=30s -n default
http_proxy= no_proxy="$(minikube ip),$(minikube service server --url),localhost" \
  curl -vk $(minikube service server --url)

kubectl get pods | grep -m2 "server-"
kubectl get svc server

# based on .proto file, make sure gateway contatins route for /$PROTO_PACKAGE_NAME.$PROTO_SERVICE_NAME
export PROTO_PACKAGE_NAME=helloworld
export PROTO_SERVICE_NAME=Greeter
export PROTO_METHOD=SayHello

http_proxy= no_proxy="$(minikube ip),$INGRESS_HOST:$INGRESS_PORT,$INGRESS_HOST,localhost" \
    curl -vk \
    -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:73.0) Gecko/20100101 Firefox/73.0" \
    -H "Accept: */*" \
    -H "Host: $INGRESS_HOST:$INGRESS_PORT" \
    -H "Accept-Language: ru,ru-RU;q=0.8,en-US;q=0.5,en;q=0.3" \
    -H "Accept-Encoding: gzip, deflate" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: content-type,grpc-timeout,x-grpc-web,x-user-agent" \
    -H "Referer: http://192.168.99.124:31895/" \
    -H "Origin: http://192.168.99.124:31895" \
    -H "Connection: keep-alive" \
    $INGRESS_HOST:$INGRESS_PORT/$PROTO_PACKAGE_NAME.$PROTO_SERVICE_NAME/$PROTO_METHOD \
    -X OPTIONS

echo "open http://$INGRESS_HOST:$INGRESS_PORT in browser"
```

Once the backend pod has started, we can verify that the gRPC-Web filter was correctly configured in its sidecar proxy like so:

```bash
kubectl get pods -n server -w | grep registry
istioctl proxy-config listeners $(kubectl get pods | grep -m2 "server-" | cut -d " " -f 1) --port 50051 -o json
```

Must exist:

```json
    "name": "envoy.grpc_web"
```

Open in browser $INGRESS_HOST:$INGRESS_PORT to see website html frontend

NOTE: ensure that web-ui connects to `$INGRESS_HOST:$INGRESS_PORT` and change `match.url.prefix` in gateway.yaml to /$PROTO_PACKAGE_NAME.$PROTO_SERVICE_NAME from proto file

## NOTE: How to build docker images which will be seen by Kubernetes directly without having to push them anywhere

just run

```bash
# NOTE: Later, when we no longer wish to use the Minikube host, we can undo this change by running: eval $(minikube docker-env -u)
eval $(minikube docker-env)
```

and now you can build docker images which will be seen by Kubernetes directly without having to push them anywhere.

## (optional) Uploading the Docker image to the cloud

See https://googlecloudrobotics.github.io/core/how-to/deploying-grpc-service.html

## (optional) How to check docker images

```bash
# Run in background container with gdb support https://stackoverflow.com/a/46676907
sudo -E docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -d --name demo_server -v "$PWD":/home/u/project_copy -p 50051:50051 --name demo_server $(minikube ip):5000/gaeus:server

# See container logs
sudo -E docker logs demo_server
```

```bash
# Run in background container with gdb support https://stackoverflow.com/a/46676907
sudo -E docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -d --name demo_ui -v "$PWD":/home/u/project_copy -p 9001:9001 $(minikube ip):5000/gaeus:web-ui
```

Now you can open `http://localhost:9001/`

```bash
# See container logs
sudo -E docker logs demo_ui

# Find container with grep
sudo -E docker ps -a | grep demo

# Run single command in container using bash with gdb support https://stackoverflow.com/a/46676907
docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined --rm --entrypoint="/bin/bash" -v "$PWD":/home/u/project_copy -w /home/u/project_copy -p 50051:50051 --name demo_server $(minikube ip):5000/gaeus:server -c pwd

# Run interactive bash inside container
docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -it --entrypoint="/bin/bash" -v "$PWD":/home/u/project_copy -w /home/u/project_copy -p 50051:50051 --name demo_server $(minikube ip):5000/gaeus:server

# OPTIONAL:
# Stop container
sudo -E docker stop demo_server

# OPTIONAL:
# Delete container
sudo -E docker rm demo_server

# OPTIONAL:
# To free disk space - Remove exited containers, dangling images and dangling volumes
# see https://www.digitalocean.com/community/tutorials/how-to-remove-docker-images-containers-and-volumes
docker rm $(docker ps -a -f status=exited -q)
docker rmi $(docker images -f dangling=true)
docker volume rm $(docker volume ls -f dangling=true)
```

## (optional) How to setup local dev env without docker

Install nodejs

```bash
# sudo apt remove node npm
# sudo rm /usr/local/bin/node # must be removed
# sudo rm /usr/local/bin/npm # must be removed
# sudo rm -rf /usr/local/lib/node_modules # must be removed
OS_ARCH=x64 # $(uname -m)
NODE_V=v10.18.1
wget https://nodejs.org/dist/$NODE_V/node-$NODE_V-linux-$OS_ARCH.tar.gz
tar -xvf node-$NODE_V-linux-$OS_ARCH.tar.gz
cd node-$NODE_V-linux-$OS_ARCH
sudo cp -rf * /usr/local/
sudo chown -R $USER /usr/local/lib/node_modules
cd -
# npm install npm -g # optional
node -v
npm -v
```

Install protobuf from sources https://developers.google.com/protocol-buffers/docs/downloads and (if exists) remove old protobuf version `apt-get remove libprotobuf-dev`

NOTE: it is better to clone https://github.com/grpc/grpc/ repo and build protobuf from grpc/third_party/protobuf

NOTE: make sure that grpc branch matches used in project

```bash
python -V # Python 2.7 or newer
sudo apt-get install autoconf automake libtool curl make g++ unzip
git clone https://github.com/protocolbuffers/protobuf.git
cd protobuf
git submodule update --init --recursive
./autogen.sh
./configure --prefix=/usr
make
make check
sudo make install
sudo ldconfig # refresh shared library cache.
protoc --version
```

Install Protocol Buffers for Go https://github.com/golang/protobuf#installation

```bash
# NOTE: you may want to use NODE_TLS_REJECT_UNAUTHORIZED=0 under proxy during `npm install`
NODE_TLS_REJECT_UNAUTHORIZED=0 \
HTTP_PROXY=http://127.0.0.1:8088 \
HTTPS_PROXY=http://127.0.0.1:8088 \
  npm install \
    --unsafe-perm binding
```

Install grpc (requres protobuf) https://github.com/grpc/grpc/blob/master/BUILDING.md

## FAQ

* I got error `libprotoc.so.17: cannot open shared object file: No such file or directory`
  Try to build protobuf as static lib or use protobuf Dockerfile

## Misc

see `chrome://flags/#allow-insecure-localhost`

see in firefox `about:preferences#privacy` and `network.websocket.allowInsecureFromHTTPS` in `about:config`

## TODO

Configure Istio to allow only registered traffic:

```bash
kubectl get configmap istio -n istio-system -o yaml | sed 's/mode: ALLOW_ANY/mode: REGISTRY_ONLY/g' | kubectl replace -n istio-system -f -
```

Create serviceentry

## TODO

export CODE_FROM_REQUEST=16125935-f88d-4375-9691-dd9aafe46402.5e54c484-4335-4c8a-b22a-eb6fd3a1086f.2aa47e2c-9dde-4b95-95d4-17c59ace967c
export CLIENT_SECRET=199c35ad-8e4b-4546-8e18-6f0d158eb364

curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=authorization_code&client_id=pkce-test&client_secret=$CLIENT_SECRET&code=$CODE_FROM_REQUEST&redirect_uri=https://keycloak.example.com:8443/authorization-code/callback&scope=openid profile User&client_id=pkce-test&client_secret=$CLIENT_SECRET" https://keycloak.example.com:8443/auth/realms/master/protocol/openid-connect/token
{"access_token":"eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI4aGRPUXBHdmU1VXlnLTZsTGVMN3A4aUFiZjV3VUJwY0dTZVo4REJuTWx3In0.eyJqdGkiOiJlNzczZGYxOC1kNGJhLTQ3NmYtOGQ0Ni05ZGMxMzg1MjJhMmIiLCJleHAiOjE1ODMyOTQ0MzMsIm5iZiI6MCwiaWF0IjoxNTgzMjkyNjMzLCJpc3MiOiJodHRwczovL2tleWNsb2FrLmV4YW1wbGUuY29tOjg0NDMvYXV0aC9yZWFsbXMvbWFzdGVyIiwiYXVkIjoiYWNjb3VudCIsInN1YiI6IjFhZmUyZTdhLTk5YTMtNDEwZS04MjYyLTcxZmRjMmJmMDkwNSIsInR5cCI6IkJlYXJlciIsImF6cCI6InBrY2UtdGVzdCIsImF1dGhfdGltZSI6MTU4MzI5MTU3NSwic2Vzc2lvbl9zdGF0ZSI6IjVlNTRjNDg0LTQzMzUtNGM4YS1iMjJhLWViNmZkM2ExMDg2ZiIsImFjciI6IjAiLCJhbGxvd2VkLW9yaWdpbnMiOlsiKiJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsib2ZmbGluZV9hY2Nlc3MiLCJ1bWFfYXV0aG9yaXphdGlvbiJdfSwicmVzb3VyY2VfYWNjZXNzIjp7ImFjY291bnQiOnsicm9sZXMiOlsibWFuYWdlLWFjY291bnQiLCJtYW5hZ2UtYWNjb3VudC1saW5rcyIsInZpZXctcHJvZmlsZSJdfX0sInNjb3BlIjoib3BlbmlkIHByb2ZpbGUgZW1haWwiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwicHJlZmVycmVkX3VzZXJuYW1lIjoiam9obl91c2VybmFtZSJ9.faHDjdTjQsCC9Qa3Zc34CM2AQTmzsp4nHST_mNF-aOzvrxdz5X0QMoGr-HsJIsOecjBEl1_75P9rc99pT7GlHdlX1nRTW170eIujgJtvRc3dr0Ywh6Q2QzD3qUtVBY8aU-1_DniE7e3cRl1z7UJ_cYWtlPHEslTuLuZtK3bIwvUg8BMzEyhwaS-IbU9p0cJnX7OxVSU0KP0YbHeL0jnKbRg9Rhm06nwI52fZOgGDqRQnryEUKLKKjfQZQ-FYZLkCMFK0OnWE8gX0zFbGCeck9dQjAibFEnAeO41Cudkm00cLycuLFPcdg6c66m5RebjIWftkAqp1e-zi08FYk6b9pw","expires_in":1799,"refresh_expires_in":1800,"refresh_token":"eyJhbGciOiJIUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI0NTVlOTg2OS0wYTJlLTQ3NWYtOGRmYi1iMWFjNGZmMjkwNDIifQ.eyJqdGkiOiIxMDVmMmI4Ni00YmU3LTQzN2YtYmJkZS04ODFkYjMzYjQ1MWUiLCJleHAiOjE1ODMyOTQ0MzQsIm5iZiI6MCwiaWF0IjoxNTgzMjkyNjM0LCJpc3MiOiJodHRwczovL2tleWNsb2FrLmV4YW1wbGUuY29tOjg0NDMvYXV0aC9yZWFsbXMvbWFzdGVyIiwiYXVkIjoiaHR0cHM6Ly9rZXljbG9hay5leGFtcGxlLmNvbTo4NDQzL2F1dGgvcmVhbG1zL21hc3RlciIsInN1YiI6IjFhZmUyZTdhLTk5YTMtNDEwZS04MjYyLTcxZmRjMmJmMDkwNSIsInR5cCI6IlJlZnJlc2giLCJhenAiOiJwa2NlLXRlc3QiLCJhdXRoX3RpbWUiOjAsInNlc3Npb25fc3RhdGUiOiI1ZTU0YzQ4NC00MzM1LTRjOGEtYjIyYS1lYjZmZDNhMTA4NmYiLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsib2ZmbGluZV9hY2Nlc3MiLCJ1bWFfYXV0aG9yaXphdGlvbiJdfSwicmVzb3VyY2VfYWNjZXNzIjp7ImFjY291bnQiOnsicm9sZXMiOlsibWFuYWdlLWFjY291bnQiLCJtYW5hZ2UtYWNjb3VudC1saW5rcyIsInZpZXctcHJvZmlsZSJdfX0sInNjb3BlIjoib3BlbmlkIHByb2ZpbGUgZW1haWwifQ.ZBW2Z3G2qPTijAShmspf9ZzeP4OC-RjgC4Aw5v7GZ9A","token_type":"bearer","id_token":"eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI4aGRPUXBHdmU1VXlnLTZsTGVMN3A4aUFiZjV3VUJwY0dTZVo4REJuTWx3In0.eyJqdGkiOiJmZWI5Yjk5OS1iNzM0LTQ0MjQtOTEzNS1kYTZmNDMxYTdhYTEiLCJleHAiOjE1ODMyOTQ0MzMsIm5iZiI6MCwiaWF0IjoxNTgzMjkyNjM0LCJpc3MiOiJodHRwczovL2tleWNsb2FrLmV4YW1wbGUuY29tOjg0NDMvYXV0aC9yZWFsbXMvbWFzdGVyIiwiYXVkIjoicGtjZS10ZXN0Iiwic3ViIjoiMWFmZTJlN2EtOTlhMy00MTBlLTgyNjItNzFmZGMyYmYwOTA1IiwidHlwIjoiSUQiLCJhenAiOiJwa2NlLXRlc3QiLCJhdXRoX3RpbWUiOjE1ODMyOTE1NzUsInNlc3Npb25fc3RhdGUiOiI1ZTU0YzQ4NC00MzM1LTRjOGEtYjIyYS1lYjZmZDNhMTA4NmYiLCJhY3IiOiIwIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsInByZWZlcnJlZF91c2VybmFtZSI6ImpvaG5fdXNlcm5hbWUifQ.Oul2z5wdeDgylLHOmMn0uiOqHH81GRupCq1Sk8OvzrXR5RnZFuGWRlrzuLweEb27AO8gZrsn5cgblcYUgMLw5RT0KhDME4uvgYmB5iPONIQkcdxPIltc21QG2bj9LiauS4sWOR5OFInYeeGtwc4dckIQucw3FqaM6UH_W3-5URYLMN91-WNKI9RmcdVVCzLUpZPIoraWED1N_BMhiu7rXgsedcKIAPQzo3n1rmRpee1HDW7iDKyqPaV-MDZfID2sk-emr1br54ntso8yyek_jigTvsLI3NBpi9y5RAJx6gjAFUkSrFkk8n9DwOtIVFa_qHcbVK9cPcvfgaaADs4jew","not-before-policy":0,"session_state":"5e54c484-4335-4c8a-b22a-eb6fd3a1086f","scope":"openid profile email"}                                                  