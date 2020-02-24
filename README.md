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

Install `minikube` https://gist.github.com/blockspacer/0237dcdea981f78f8c3ea80b8b1d037d#install-minikube

Install istio https://gist.github.com/blockspacer/0237dcdea981f78f8c3ea80b8b1d037d#install-istio

For istio on minikube follow https://istio.io/docs/setup/platform-setup/minikube/

Add istioctl to PATH https://gist.github.com/blockspacer/0237dcdea981f78f8c3ea80b8b1d037d#add-istioctl-to-path

Enable `registry` addon for `minikube` as in https://minikube.sigs.k8s.io/docs/tasks/docker_registry/

Tested with `GRPC_RELEASE_TAG=v1.26.x`

We can now simply deploy the above configurations in the following order.

Note that once we deploy this service over Istio, the grpc- prefix in the Service port name will allow Istio to recognize this as a gRPC service.

```bash
minikube stop
# OR minikube delete
# Use `--insecure-registry='192.168.39.0/24'`, see https://minikube.sigs.k8s.io/docs/tasks/docker_registry/
minikube start --alsologtostderr --kubernetes-version v1.12.10 --memory=12288 --cpus=2 --disk-size 25GB --vm-driver virtualbox \
  --extra-config='apiserver.enable-admission-plugins=LimitRanger,NamespaceExists,NamespaceLifecycle,ResourceQuota,ServiceAccount,DefaultStorageClass,MutatingAdmissionWebhook' \
  --extra-config=apiserver.authorization-mode=RBAC \
  --insecure-registry='localhost' \
  --insecure-registry='127.0.0.1' \
  --insecure-registry "192.168.39.0/24"
# OPTIONAL: open dashboard
minikube addons enable dashboard && kubectl get pods --all-namespaces | grep dashboard && sleep 15 && minikube dashboard
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

Now the kubernetes part. Copy the clusterIP of the registry service running on kube-system namespace and put it on the pod spec's image as in https://amritbera.com/journal/minikube-insecure-registry.html:

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

Add result of `echo $(minikube ip)` into `NO_PROXY` in `/etc/systemd/system/docker.service.d/http-proxy.conf` or `~/.docker/config.json`

```bash
kubectl config use-context minikube

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
# Run this command in a different terminal, because the minikube tunnel feature will block your terminal to output diagnostic information about the network:
minikube tunnel
# Sometimes minikube does not clean up the tunnel network properly. To force a proper cleanup:
minikube tunnel --cleanup

istioctl manifest apply
# Enable automatic sidecar injection for defaultnamespace
kubectl label namespace default istio-injection=enabled
```

## Build docker images

```bash
sudo -E docker build \
  --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* \
  -f docker/cxx_build_env.Dockerfile \
  --tag $(minikube ip):5000/gaeus:cxx_build_env . \
  --no-cache

sudo -E docker tag $(minikube ip):5000/gaeus:cxx_build_env gaeus:cxx_build_env

# grpc_build_env is OPTIONAL
# NOTE: you can place already cloned grpc into `GRPC_LOCAL_TO_PROJECT_PATH` and enable `BUILD_GRPC_FROM_SOURCES`
# sudo -E docker build --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* --build-arg GRPC_LOCAL_TO_PROJECT_PATH=grpc --build-arg BUILD_GRPC_FROM_SOURCES=False --build-arg BUILD_GRPC_WEB_FROM_SOURCES=False -f docker/grpc_build_env.Dockerfile --tag $(minikube ip):5000/gaeus:grpc_build_env . --no-cache

export MY_IP=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')

sudo -E docker build \
  --build-arg BUILD_TYPE=Debug \
  --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* \
  --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
  --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
  -f docker/web-ui.Dockerfile \
  --tag $(minikube ip):5000/gaeus:web-ui . \
  --no-cache

# TODO: INSTALL_GRPC_FROM_CONAN
# NOTE: --build-arg BUILD_TYPE=Debug
# NOTE: to add custom conan repo replace YOUR_REPO_URL_HERE in: --build-arg CONAN_EXTRA_REPOS="conan-local http://YOUR_REPO_URL_HERE:8081/artifactory/api/conan/conan False" --build-arg CONAN_EXTRA_REPOS_USER="user -p password -r conan-local admin"
sudo -E docker build \
  --build-arg BUILD_TYPE=Debug \
  --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* \
  --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
  --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
  -f docker/server.Dockerfile \
  --tag $(minikube ip):5000/gaeus:server . \
  --no-cache
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

## Upload yaml files

```bash
cd istio
# Tag your images with $(minikube ip):5000/image-name and push them.
# Inside k8s your images will be available from localhost:5000 registry, so your k8s manifests should specify image as `localhost:5000/image-name`.
export REGISTRY_IP=localhost # Requires pushing of images to registry
#export REGISTRY_IP=$(minikube ip) # Requires `eval $(minikube docker-env)`
export REGISTRY_PORT=5000
cat web-ui.yaml | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" | kubectl apply -f -
kubectl get pods | grep -m2 "web-ui-"
kubectl get svc web-ui
# check `minikube service ...... --url` via curl
http_proxy= no_proxy="$(minikube ip),$(minikube service web-ui --url),localhost" \
  curl -vk $(minikube service web-ui --url)
cat filter.yaml | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" | kubectl apply -f -
cat server.yaml | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" | kubectl apply -f <(istioctl kube-inject -f -)
cat gateway.yaml | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" | kubectl apply -f -

# use $INGRESS_HOST:$INGRESS_PORT from https://istio.io/docs/tasks/traffic-management/ingress/ingress-control/
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export INGRESS_HOST=$(minikube ip)

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
