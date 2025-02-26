#!/bin/bash

KUBE_CONTEXT=docker-desktop
NAMESPACE=workflows

kubectl create namespace $NAMESPACE --context=$KUBE_CONTEXT
kubectl label namespace $NAMESPACE istio-injection=enabled --context=$KUBE_CONTEXT

# Install services
helm upgrade --install --kube-context=$KUBE_CONTEXT -n=$NAMESPACE --create-namespace argo-workflows .

# Forward the Server's port to access the UI:
# kubectl -n $NAMESPACE --context=$KUBE_CONTEXT port-forward service/argo-workflows-server 2746:2746
