Reliability Testing with argo-workflows and Istio
===

Getting Started
---

In order to run this demo, you'll need a Docker environment like Docker Desktop, kubectl, istioctl and helm.


### Install Istio
If Istio is already running in your cluster, skip this step.
```
istioctl install --context=docker-desktop --set profile=demo --set values.pilot.env.ENABLE_NATIVE_SIDECARS=true -y
```

### Run the install script
Run the following script to install the K6 operator, Argo Workflows and Minio (S3-compatible persistence layer for storing artifacts) into the `docker-desktop` Kubernetes context.
```
bash install.sh
```

### Run the update script to install Kubernetes resources
Run the following command to install the Helm chart into your `docker-desktop` Kubernetes context.
```
bash update.sh
```

