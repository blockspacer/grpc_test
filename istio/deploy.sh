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

export MY_IP=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')
echo "my ip is $MY_IP..."

echo "apply configmap..."

cat authservice-configmap-template-for-authn.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl apply -f -

echo "apply web-ui..."

cat web-ui.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl apply -f -

echo "wait pod web-ui..."

# NOTE: waits by pod label, see -lapp=...
kubectl wait pod -lapp=web-ui --for=condition=Ready --timeout=30s -n default

#echo "apply outbound..."
#
#cat outbound.yaml \
#  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
#  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
#  | sed "s/{{MY_IP}}/$MY_IP/g" \
#  | kubectl apply -f -

echo "apply sidecar..."

cat app-external-authz-envoyfilter-sidecar.yaml  \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | sed "s/{{INGRESS_HOST}}/$INGRESS_HOST/g" \
  | sed "s/{{INGRESS_PORT}}/$SECURE_INGRESS_PORT/g" \
  | kubectl apply -f -

echo "apply auth..."

cat auth.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | sed "s/{{INGRESS_HOST}}/$INGRESS_HOST/g" \
  | sed "s/{{INGRESS_PORT}}/$SECURE_INGRESS_PORT/g" \
  | kubectl apply -f -

echo "apply filter..."

cat filter.yaml  \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | sed "s/{{INGRESS_HOST}}/$INGRESS_HOST/g" \
  | sed "s/{{INGRESS_PORT}}/$SECURE_INGRESS_PORT/g" \
  | kubectl apply -f -

echo "apply server..."

cat server.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl apply -f <(istioctl kube-inject -f -)

echo "wait pod server..."

# NOTE: waits by pod label, see -lapp=...
kubectl wait pod -lapp=server --for=condition=Ready --timeout=30s -n default

echo "apply gateway..."

cat gateway.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl apply -f -

echo "open in browser https://$INGRESS_HOST:$SECURE_INGRESS_PORT/"

