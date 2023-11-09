#!/bin/bash

set -e

cd $(dirname $0)

echo $GITHUB_ACTION
if [ -z $GITHUB_ACTION ]; then
    STAGINGVERSION=latest LOAD_TO_KIND=true make all
else
    STAGINGVERSION=latest LOAD_TO_KIND=true DOCKER_CACHE_ARGS="--cache-from=type=gha --cache-to=type=gha,mode=max" make all
fi
kubectl apply -f deploy/csi-driver.yaml
kubectl apply -f deploy/csi-driver-daemonset.yaml

while [[ $(kubectl get ds -n mfcp-system meta-fuse-csi-plugin -o 'jsonpath={..status.numberReady}') != "1" ]]; do echo "waiting for csi-plugin" && sleep 1; done

make test-examples
