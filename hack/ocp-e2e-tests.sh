#!/bin/bash

# Make sure to set the IMAGE_REPO env variable to your quay.io username
# before running this script.

# Additionally, the e2e tests rely on extra nics being configured on the
# node. If running from dev-scripts, it will be necessary to configure it to
# deploy the extra nics.
# See https://github.com/openshift-metal3/dev-scripts/pull/1286 for an example.

set -ex

export KUBEVIRT_PROVIDER=external
export IMAGE_BUILDER=podman
export DEV_IMAGE_REGISTRY=quay.io
export KUBEVIRTCI_RUNTIME=podman
export SSH=./hack/ssh.sh
export PRIMARY_NIC=enp2s0
export FIRST_SECONDARY_NIC=enp3s0
export SECOND_SECONDARY_NIC=enp4s0

SKIPPED_TESTS="user-guide|bridged"

if oc get ns openshift-ovn-kubernetes &> /dev/null; then
    # We are using OVNKubernetes -> use enp1s0 as primary nic
    export PRIMARY_NIC=enp1s0
    SKIPPED_TESTS+="|NodeNetworkConfigurationPolicy bonding default interface|\
with ping fail|\
when connectivity to default gw is lost after state configuration|\
when name servers are lost after state configuration|\
when name servers are wrong after state configuration"
fi

# Apply machine configs and wait until machine config pools got updated
old_mcp_generation=$(oc get mcp master -o jsonpath={.metadata.generation})
if oc create -f test/e2e/machineconfigs.yaml; then
    # If MCs could be created, wait until the MCP are aware of new machine configs
    while [ "$old_mcp_generation" -eq "$(oc get mcp master -o jsonpath={.metadata.generation})" ]; do 
        echo "waiting for MCP update to start..."; 
        sleep 1; 
    done
fi
while ! oc wait mcp --all --for=condition=Updated --timeout -1s; do sleep 1; done

make cluster-sync-operator
# Will fail on subsequent runs, this is fine.
oc create -f build/_output/manifests/scc.yaml || :
oc create -f test/e2e/nmstate.yaml
# On first deployment, it can take a while for all of the pods to come up
# First wait for the handler pods to be created
while ! oc get pods -n nmstate | grep handler; do sleep 1; done
# Then wait for them to be ready
while oc get pods -n nmstate | grep "0/1"; do sleep 1; done
# NOTE(bnemec): The test being filtered with "bridged" was re-enabled in 4.8, but seems to be consistently failing on OCP.
make test-e2e-handler E2E_TEST_ARGS="--skip=\"${SKIPPED_TESTS}\"" E2E_TEST_TIMEOUT=120h
