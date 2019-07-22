#!/bin/bash
set -e

BASEDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)
source "${BASEDIR}/scripts/functions.sh"

# ------------------------------------------------------------------------------
# Introduction
# ------------------------------------------------------------------------------

echo -e "This script will help automate the process of setting up a Kubernetes cluster on DigitalOcean." \
        "It will install any local dependencies needed, and then prompt for the configuration of each component as necessary." | fold -s

read -p $'\033[32mPress enter to continue...\033[39m'
echo

# ------------------------------------------------------------------------------
# Check Dependencies: Brew, Kubectl, Helm, Doctl.
# ------------------------------------------------------------------------------

"${BASEDIR}"/scripts/dependency-check.sh

# ------------------------------------------------------------------------------
# Create Cluster
# ------------------------------------------------------------------------------
echo "A Kubernetes cluster is required before proceeding with this script."
if ask "Would you like to create a new Kubernetes cluster?"; then
  echo
  "${BASEDIR}"/scripts/create-cluster.sh
else # Copy Config
  echo
  if ask "Add an existing Kubernetes config to the kubectl context?" Y; then
    echo
    "${BASEDIR}"/scripts/copy-config.sh
  fi
fi
echo

# ------------------------------------------------------------------------------
# Helm/Tiller Setup
# ------------------------------------------------------------------------------
echo "Helm is a package manager for Kubernetes used to streamline the installation and managment of Kubernetes applications."
if ask "Install Helm and initialize Tiller on the cluster?" Y; then
  echo
  "${BASEDIR}"/scripts/install-helm-tiller.sh
fi
echo

# ------------------------------------------------------------------------------
# Nginx Ingress Setup
# ------------------------------------------------------------------------------
echo "Inbound cluster traffic must be routed through a Kubernetes Ingress in order to publicly expose applications."
echo -e "\033[31mInstalling the Nginx Ingress will create a DigitalOcean Load Balancer by association.\033[39m"
if ask "Install the Nginx Ingress controller?" Y; then
  echo
  "${BASEDIR}"/scripts/install-nginx-ingress.sh
fi
echo

# ------------------------------------------------------------------------------
# Create DNS Record for Ingress Setup
# ------------------------------------------------------------------------------
echo "Traffic routed from a DNS needs to be forwarded to a load balancer via an A record."
echo "The A record must be present BEFORE intializing Flux in order to prevent issues when fetching TLS certificates."
if ask "Create a DNS A record for the cluster's Nginx Ingress?" Y ;then
  echo
  "${BASEDIR}"/scripts/create-dns.sh
fi
echo

# ------------------------------------------------------------------------------
# Install Cert Manager
# ------------------------------------------------------------------------------
echo "Cert Manager is used to encrypt traffic via HTTPS using TLS certificates."
echo "The Cert Manager pods must be online BEFORE Flux picks up the configuration stored in the Git repository."
if ask "Install Cert Manager onto the cluster?" Y ;then
  echo
  "${BASEDIR}"/scripts/install-cert-manager.sh
fi
echo

# ------------------------------------------------------------------------------
# Install Flux
# ------------------------------------------------------------------------------
echo "Flux is a package that will manage the state of a Kubernetes cluster."
echo "It will monitor a repository for changes and automatically apply those changes to the cluster."
if ask "Install Flux for the current repository?" Y ;then
  echo
  "${BASEDIR}"/scripts/install-flux.sh
fi
echo

# ------------------------------------------------------------------------------
# Final Steps
# ------------------------------------------------------------------------------

echo -e "\033[33mIf a Sealed Secrets master key already exists, please apply the key BEFORE giving Flux access to the Git repository.\033[39m"
echo -e "\033[32mThe Kubernetes cluster is ready for use!\033[39m"
echo
