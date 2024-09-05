#!/bin/bash

set -eu

cd $(dirname $0)

function wait_for_pod_becom_ready() {
    while [[ $(kubectl get pods $1 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 1; done
}

function wait_for_fuse_mounted() {
    while [[ ! $(kubectl exec $1 -c $2 -- /bin/mount | grep fuse) ]]; do echo "waiting for mount" && sleep 1; done
}

MANIFEST_DIR=$1 # path to example manifest
MAFNIFEST_FILENAME=$2
POD_NAME=$3
PROVIDER_CONTAINER=$4
PROVIDED_FILENAME=$5
MOUNTED_CONTAINER=$6
MOUNTED_FILENAME=$7

clean_up () {
    ARG=$?
    kubectl delete -f ./${MAFNIFEST_FILENAME}
    exit $ARG
}
trap clean_up EXIT

cd $MANIFEST_DIR

# Start to check the pod
echo "Checking Pod \"$POD_NAME\"..."
kubectl apply -f ./${MAFNIFEST_FILENAME}

# Waiting pod becomes ready
wait_for_pod_becom_ready $POD_NAME
echo "Pod is ready."

# Waiting FUSE is mounted to the target container
wait_for_fuse_mounted $POD_NAME $MOUNTED_CONTAINER
echo "FUSE is mounted."

# Validating content.
BASE_CONTENT=$(kubectl exec $POD_NAME -c $PROVIDER_CONTAINER -- cat $PROVIDED_FILENAME)
MOUNTED_CONTENT=$(kubectl exec $POD_NAME -c $MOUNTED_CONTAINER -- cat $MOUNTED_FILENAME)

if [ "$BASE_CONTENT" != "$MOUNTED_CONTENT" ]; then
    echo "Content unmatched!! expected=\"${BASE_CONTENT}\" actual=\"${MOUNTED_CONTENT}\""
    exit 1
fi

echo "OK."

exit 0
