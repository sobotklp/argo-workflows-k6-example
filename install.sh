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
helm repo update
helm upgrade --install --kube-context=$KUBE_CONTEXT -n=argo-workflows argo-workflows argoproj/argo-workflows --set-json 'server.authModes=["client","server"]' --set-json 'workflow.serviceAccount={"create":true, "name": "argo-workflow"}'
helm upgrade --install --kube-context=$KUBE_CONTEXT k6-operator grafana/k6-operator --set-json 'podAnnotations={"sidecar.istio.io/inject": "false"}'
