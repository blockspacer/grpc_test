# Tag your images with $(minikube ip):5000/image-name and push them.
# Inside k8s your images will be available from localhost:5000 registry, so your k8s manifests should specify image as `localhost:5000/image-name`.
export REGISTRY_IP=localhost # Requires pushing of images to registry
#export REGISTRY_IP=$(minikube ip) # Requires `eval $(minikube docker-env)`
export REGISTRY_PORT=5000

cat gateway.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -
cat server.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -
cat web-ui.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -
cat filter.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -
cat authservice-configmap-template-for-authn.yaml \
  | sed "s/{{REGISTRY_IP}}/$REGISTRY_IP/g" \
  | sed "s/{{REGISTRY_PORT}}/$REGISTRY_PORT/g" \
  | kubectl delete --ignore-not-found=true -f -
kubectl delete destinationrules --all -n default
kubectl delete gateway --all -n default
kubectl delete virtualservices --all -n default
kubectl delete pod --all -n default