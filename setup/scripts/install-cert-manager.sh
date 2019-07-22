#!/bin/bash

BASEDIR=$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)")
source "${BASEDIR}/scripts/functions.sh"

# -----------------------------------------------------------------------------
# Install Cert Manager
# -----------------------------------------------------------------------------
echo "Installing the Cert Manager Custom Resource Definition..."
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

echo "Adding the Cert Manager chart repository to Helm..."
helm repo add jetstack https://charts.jetstack.io
echo

echo "Installing Cert Manager..."
helm upgrade --install cert-manager --namespace cert-manager jetstack/cert-manager > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
  echo -e "\033[32mCert Manager has been installed.\033[39m"
else
  echo -e "\033[31mThere was a problem installing Cert Manager.\033[39m"
  exit 1
fi

kubectl rollout status deployment/cert-manager -n cert-manager --watch > /dev/null 2>&1 & \
spinner "Waiting for the Cert Manager pods to initialize"

echo -e "\033[32mCert Manager is ready.\033[39m"