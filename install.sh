#!/bin/bash

KUBE_CONTEXT=docker-desktop
NAMESPACE=argo-workflows

# If you use Istio, ensure you have native sidecars enabled, otherwise k6 pods will not immediately have network access
#istioctl install --context=docker-desktop --set profile=demo --set values.pilot.env.ENABLE_NATIVE_SIDECARS=true -y

# Create namespace with auto-injection
kubectl create namespace $NAMESPACE --context=$KUBE_CONTEXT
kubectl label namespace $NAMESPACE istio-injection=enabled --context=$KUBE_CONTEXT
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm --context=$KUBE_CONTEXT
kubectl annotate namespace $NAMESPACE meta.helm.sh/release-name=argo-workflows --context=$KUBE_CONTEXT
kubectl annotate namespace $NAMESPACE meta.helm.sh/release-namespace=argo-workflows --context=$KUBE_CONTEXT


helm repo add grafana https://grafana.github.io/helm-charts
helm repo add argoproj https://argoproj.github.io/argo-helm
helm repo add minio https://charts.min.io/
helm repo update

# Toy setup of Minio. Argo Workflows will use this for artifact storage
helm upgrade --install --kube-context=$KUBE_CONTEXT -n=argo-artifacts argo-artifacts minio/minio --create-namespace --set resources.requests.memory=512Mi --set replicas=1 --set persistence.enabled=false --set mode=standalone --set rootUser=rootuser,rootPassword=rootpass123 --set service.type=LoadBalancer --set fullnameOverride=argo-artifacts --set-json 'buckets=[{"name": "argo-artifacts"}]'

# Now that minio is installed, you should be able to access it using the AWS CLI:
# AWS_ACCESS_KEY_ID=rootuser AWS_SECRET_ACCESS_KEY=rootpass123 aws s3 --endpoint-url http://localhost:9000 ls
ACCESS_KEY=$(kubectl get secret argo-artifacts --context=$KUBE_CONTEXT -n argo-artifacts -o jsonpath="{.data.rootUser}" | base64 --decode)
SECRET_KEY=$(kubectl get secret argo-artifacts --context=$KUBE_CONTEXT -n argo-artifacts -o jsonpath="{.data.rootPassword}" | base64 --decode)

# Create a secret in the workflows namespace with the Minio credentials.
# Workflows will need this to access artifact storage.
kubectl create secret --context=$KUBE_CONTEXT -n workflows generic my-minio-cred --from-literal=access-key="$ACCESS_KEY" --from-literal=secret-key="$SECRET_KEY"

helm upgrade --install --kube-context=$KUBE_CONTEXT -n=argo-workflows argo-workflows argoproj/argo-workflows --set server.serviceType=LoadBalancer --set-json 'server.authModes=["client","server"]' --set-json 'workflow.serviceAccount={"create":true, "name": "argo-workflow"}' --set-json 'artifactRepository={"s3": {"bucket": "argo-artifacts", "endpoint": "argo-artifacts.argo-artifacts:9000", "insecure": true, "accessKeySecret": {"name": "my-minio-cred", "key": "access-key"}, "secretKeySecret": {"name": "my-minio-cred", "key": "secret-key"}}}'
helm upgrade --install --kube-context=$KUBE_CONTEXT k6-operator grafana/k6-operator --set-json 'podAnnotations={"sidecar.istio.io/inject": "false"}'
