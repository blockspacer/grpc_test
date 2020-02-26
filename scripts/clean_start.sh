function _out() {
  echo "$(date +'%F %H:%M:%S') $@"
}

function checkPrerequisites() {
    MISSING_TOOLS=""
    git --version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} git"
    curl --version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} curl"
    which sed &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} sed"
    docker -v &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} docker"
    unzip -version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} unzip"
    kubectl version --client=true &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} kubectl"
    minikube version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} minikube"
    if [[ -n "$MISSING_TOOLS" ]]; then
      _out "Some tools (${MISSING_TOOLS# }) could not be found, please install them first"
      exit 1
    else
      _out You have all necessary prerequisites installed
    fi
    if ! kubectl describe namespace default | grep istio-injection=enabled > /dev/null ; then
       _out "Istio automatic sidecar injection needs to be enabled. See documentation/SetupLocalEnvironment.md"
    fi
}

checkPrerequisites

mkdir ~/job_projects

cd ~/job_projects

git clone --recurse-submodules https://github.com/blockspacer/grpc_test.git

git clone --recurse-submodules https://github.com/blockspacer/conan-grpcweb.git

git clone --recurse-submodules https://github.com/blockspacer/conan_grpc.git

git clone --recurse-submodules https://github.com/blockspacer/conan_zlib.git

git clone --recurse-submodules https://github.com/blockspacer/conan_protobuf.git

git clone --recurse-submodules https://github.com/blockspacer/conan_openssl.git

git clone --recurse-submodules https://github.com/blockspacer/conan_c_ares.git

sudo mkdir -p /data/artifactory
sudo chmod 0755 /data/artifactory
# Artifactory runs as user 1030:1030 by default. When passing a volume to the Artifactory container, this directory (on the host) must be writable by the Artifactory user.
sudo chown 1030:1030 /data/artifactory
#  artifactory-cpp-ce - JFrog Artifactory Community Edition for C/C++, a completely free of charge server for Conan repositories.
sudo docker pull docker.bintray.io/jfrog/artifactory-cpp-ce
sudo docker run -d --restart=always --name artifactory -v /data/artifactory:/var/opt/jfrog/artifactory -p 8081:8081 -e EXTRA_JAVA_OPTIONS='-Xms512m -Xmx2g -Xss256k -XX:+UseG1GC' docker.bintray.io/jfrog/artifactory-cpp-ce
docker logs -f artifactory

export CONAN_REVISIONS_ENABLED=1
conan remote add conan-local http://localhost:8081/artifactory/api/conan/conan False
conan remote list
conan user -p password1 -r conan-local admin

visit http://localhost:8081 to open configuration wizard User:admin. Password:password
NOTE: you can skip Configure a Proxy Server step, read https://www.jfrog.com/confluence/display/RTF6X/Configuring+a+Reverse+Proxy
turn off anonymous access in the Admin> Security Configuration page http://localhost:8081/artifactory/webapp/#/admin/security/general
open http://localhost:8081/artifactory/webapp/#/artifacts/browse/tree/General/conan and click the Set Me Up button as in https://www.jfrog.com/confluence/display/RTF/Using+Artifactory#UsingArtifactory-SetMeUp

CHANGE conan-local password to password1

curl -Lo minikube http://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube
sudo install minikube /usr/local/bin
minikube status
minikube stop
# OR minikube delete
minikube start --alsologtostderr --kubernetes-version v1.12.10 --memory=12288 --cpus=4 --disk-size 25GB --vm-driver virtualbox \
  --extra-config='apiserver.enable-admission-plugins=LimitRanger,NamespaceExists,NamespaceLifecycle,ResourceQuota,ServiceAccount,DefaultStorageClass,MutatingAdmissionWebhook' \
  --extra-config=apiserver.authorization-mode=RBAC \
  --insecure-registry='localhost' \
  --insecure-registry='127.0.0.1' \
  --insecure-registry "192.168.39.0/24"

kubectl config use-context minikube

# see http://rastko.tech/kubernetes/2019/01/01/minikube-on-mac.html
minikube addons enable ingress

# Use `--insecure-registry='192.168.39.0/24'`
# see https://minikube.sigs.k8s.io/docs/tasks/docker_registry/
minikube addons enable registry

curl -L https://git.io/getLatestIstio | sh -
cd istio*
echo 'export PATH=$(pwd)/bin:$PATH' >> ~/.bashrc
# OR
# sudo cp ./bin/istioctl /usr/local/bin/istioctl
# sudo chmod +x /usr/local/bin/istioctl
istioctl version

istioctl manifest apply

# see https://istio.io/docs/setup/getting-started/
kubectl get svc -n istio-system

# ensure corresponding Kubernetes pods are deployed and have a STATUS of Running
kubectl get pods -n istio-system

kubectl label namespace default istio-injection=enabled

# To install Agones, a service account needs permission to create some special RBAC resource types.
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:default

kubectl create namespace agones-system

kubectl apply -f https://raw.githubusercontent.com/googleforgames/agones/release-1.2.0/install/yaml/install.yaml

# kubectl create -f https://raw.githubusercontent.com/googleforgames/agones/release-1.2.0/examples/simple-udp/gameserver.yaml

kubectl describe --namespace agones-system pods

kubectl get gameservers

kubectl describe gameserver

kubectl get gs

# echo "hello" | nc -u $(minikube ip) 7331

# NOTE: Later, when we no longer wish to use the Minikube host, we can undo this change by running: eval $(minikube docker-env -u)
# eval $(minikube docker-env)

export MY_IP=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')

echo $MY_IP

cd grpc_test

sudo -E docker build \
  --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* \
  -f docker/cxx_build_env.Dockerfile \
  --tag gaeus:cxx_build_env . \
  --no-cache

sudo -E docker tag gaeus:cxx_build_env $(minikube ip):5000/gaeus:cxx_build_env

cd ../conan_build_env

sudo -E docker build \
    --build-arg CONAN_INSTALL="conan install --profile gcc --build missing" \
    --build-arg CONAN_CREATE="conan create --profile gcc --build missing" \
    --build-arg CONAN_UPLOAD="conan upload --all -r=conan-local -c --retry 3 --retry-wait 10 --force" \
    --build-arg BUILD_TYPE=Release \
    -f conan_build_env.Dockerfile --tag conan_build_env . --no-cache

cd ../conan_c_ares

sudo -E docker build \
    --build-arg PKG_NAME=c-ares/cares-1_15_0 \
    --build-arg PKG_CHANNEL=conan/stable \
    --build-arg PKG_UPLOAD_NAME=c-ares/cares-1_15_0@conan/stable \
    --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
    --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
    --build-arg CONAN_INSTALL="conan install --profile gcc --build missing" \
    --build-arg CONAN_CREATE="conan create --profile gcc --build missing" \
    --build-arg CONAN_UPLOAD="conan upload --all -r=conan-local -c --retry 3 --retry-wait 10 --force" \
    --build-arg BUILD_TYPE=Release \
    -f conan_c_ares.Dockerfile --tag conan_c_ares . --no-cache

cd ../conan_protobuf

sudo -E docker build \
    --build-arg PKG_NAME=protobuf/v3.9.1 \
    --build-arg PKG_CHANNEL=conan/stable \
    --build-arg PKG_UPLOAD_NAME=protobuf/v3.9.1@conan/stable \
    --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
    --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
    --build-arg CONAN_INSTALL="conan install --profile gcc --build missing" \
    --build-arg CONAN_CREATE="conan create --profile gcc --build missing" \
    --build-arg CONAN_UPLOAD="conan upload --all -r=conan-local -c --retry 3 --retry-wait 10 --force" \
    --build-arg BUILD_TYPE=Release \
    -f conan_protobuf.Dockerfile --tag conan_protobuf . --no-cache

cd ../conan_zlib

sudo -E docker build \
    --build-arg PKG_NAME=zlib/v1.2.11 \
    --build-arg PKG_CHANNEL=conan/stable \
    --build-arg PKG_UPLOAD_NAME=zlib/v1.2.11@conan/stable \
    --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
    --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
    --build-arg CONAN_INSTALL="conan install --profile gcc --build missing" \
    --build-arg CONAN_CREATE="conan create --profile gcc --build missing" \
    --build-arg CONAN_UPLOAD="conan upload --all -r=conan-local -c --retry 3 --retry-wait 10 --force" \
    --build-arg BUILD_TYPE=Release \
    -f conan_zlib.Dockerfile --tag conan_zlib . --no-cache

cd ../conan_openssl

sudo -E docker build \
    --build-arg PKG_NAME=openssl/OpenSSL_1_1_1-stable \
    --build-arg PKG_CHANNEL=conan/stable \
    --build-arg PKG_UPLOAD_NAME=openssl/OpenSSL_1_1_1-stable@conan/stable \
    --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
    --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
    --build-arg CONAN_INSTALL="conan install --profile gcc --build missing" \
    --build-arg CONAN_CREATE="conan create --profile gcc --build missing" \
    --build-arg CONAN_UPLOAD="conan upload --all -r=conan-local -c --retry 3 --retry-wait 10 --force" \
    --build-arg BUILD_TYPE=Release \
    -f conan_openssl.Dockerfile --tag conan_openssl . --no-cache

cd ../conan_grpc

sudo -E docker build \
    --build-arg PKG_NAME=grpc_conan/v1.26.x \
    --build-arg PKG_CHANNEL=conan/stable \
    --build-arg PKG_UPLOAD_NAME=grpc_conan/v1.26.x@conan/stable \
    --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
    --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
    --build-arg CONAN_UPLOAD="conan upload --all -r=conan-local -c --retry 3 --retry-wait 10 --force" \
    --build-arg BUILD_TYPE=Release \
    -f grpc_conan_source.Dockerfile --tag grpc_conan_repoadd_source_install . --no-cache

sudo -E docker build \
    --build-arg PKG_NAME=grpc_conan/v1.26.x \
    --build-arg PKG_CHANNEL=conan/stable \
    --build-arg PKG_UPLOAD_NAME=grpc_conan/v1.26.x@conan/stable \
    --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
    --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
    --build-arg CONAN_UPLOAD="conan upload --all -r=conan-local -c --retry 3 --retry-wait 10 --force" \
    --build-arg BUILD_TYPE=Release \
    -f grpc_conan_build.Dockerfile --tag grpc_conan_build_package_export_test_upload . --no-cache

cd ../conan-grpcweb/

sudo -E docker build \
    --build-arg PKG_NAME=grpcweb_conan \
    --build-arg PKG_CHANNEL=conan/stable \
    --build-arg PKG_UPLOAD_NAME=grpcweb_conan/1.0.7@conan/stable \
    --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
    --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
    --build-arg CONAN_UPLOAD="conan upload --all -r=conan-local -c --retry 3 --retry-wait 10 --force" \
    --build-arg BUILD_TYPE=Release \
    -f conan_grpcweb_source.Dockerfile --tag conan_grpcweb_repoadd_source_install . --no-cache

sudo -E docker build \
    --build-arg PKG_NAME=grpcweb_conan/1.0.7 \
    --build-arg PKG_CHANNEL=conan/stable \
    --build-arg PKG_UPLOAD_NAME=grpcweb_conan/1.0.7@conan/stable \
    --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
    --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
    --build-arg CONAN_UPLOAD="conan upload --all -r=conan-local -c --retry 3 --retry-wait 10 --force" \
    --build-arg BUILD_TYPE=Release \
    -f conan_grpcweb_build.Dockerfile --tag conan_grpcweb_build_package_export_test_upload . --no-cache

cd ../grpc_test

sudo -E docker build \
  --build-arg BUILD_TYPE=Release \
  --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* \
  --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
  --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
  -f docker/web-ui.Dockerfile \
  --tag gaeus:web-ui . \
  --no-cache

sudo -E (docker rmi $(minikube ip):5000/gaeus:web-ui || true)
sudo -E docker tag gaeus:web-ui $(minikube ip):5000/gaeus:web-ui

sudo -E docker build \
  --build-arg BUILD_TYPE=Release \
  --build-arg NO_PROXY=$(minikube ip),localhost,127.0.0.*,10.*,192.168.* \
  --build-arg CONAN_EXTRA_REPOS="conan-local http://$MY_IP:8081/artifactory/api/conan/conan False" \
  --build-arg CONAN_EXTRA_REPOS_USER="user -p password1 -r conan-local admin" \
  -f docker/server.Dockerfile \
  --tag gaeus:server . \
  --no-cache

sudo -E (docker rmi $(minikube ip):5000/gaeus:server || true)
sudo -E docker tag gaeus:server $(minikube ip):5000/gaeus:server

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

sudo -E docker push $(minikube ip):5000/gaeus:server

sudo -E docker push $(minikube ip):5000/gaeus:web-ui

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