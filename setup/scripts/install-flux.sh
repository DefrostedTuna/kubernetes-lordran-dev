#!/bin/bash

BASEDIR=$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)")
source "${BASEDIR}/scripts/functions.sh"

# ------------------------------------------------------------------------------
# Install Flux
# ------------------------------------------------------------------------------
helm repo add fluxcd https://fluxcd.github.io/flux > /dev/null 2>&1

helm install --name flux \
--set rbac.create=true \
--set helmOperator.create=true \
--set helmOperator.createCRD=true \
--set git.url=git@github.com:DefrostedTuna/kubernetes-lordran-dev \
--set git.pollInterval=1m \
--set registry.pollInterval=1m \
--wait \
--namespace flux \
fluxcd/flux > /dev/null 2>&1 & \
spinner "Installing Flux onto the cluster, please wait"

echo "Please add the following Deploy Key to the Git repository:"
kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2

echo -e "\033[32mFlux is ready!\033[39m"