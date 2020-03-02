# Tag your images with $(minikube ip):5000/image-name and push them.
# Inside k8s your images will be available from localhost:5000 registry, so your k8s manifests should specify image as `localhost:5000/image-name`.
export REGISTRY_IP=localhost # Requires pushing of images to registry
#export REGISTRY_IP=$(minikube ip) # Requires `eval $(minikube docker-env)`
export REGISTRY_PORT=5000

# use $INGRESS_HOST:$INGRESS_PORT from https://istio.io/docs/tasks/traffic-management/ingress/ingress-control/
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export INGRESS_HOST=$(minikube ip)

export MY_IP=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')

echo "gateway..."
cat gateway.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -

echo "server..."
cat server.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -

echo "web-ui..."
cat web-ui.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -

echo "envoyfilter..."
cat app-external-authz-envoyfilter-sidecar.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -

echo "filter..."
cat filter.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -

echo "auth..."
cat auth.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -

echo "configmap..."
cat authservice-configmap-template-for-authn.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -

# echo "outbound..."
# cat outbound.yaml \
#   | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
#   | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
#   | sed "s/{{MY_IP}}/$MY_IP/g" \
#   | kubectl delete --ignore-not-found=true -f -

kubectl delete destinationrules --all -n default

kubectl delete gateway --all -n default

kubectl delete virtualservices --all -n default

kubectl delete pod --all -n default
