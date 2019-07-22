#!/bin/bash
BASEDIR=$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)")
source "${BASEDIR}/scripts/functions.sh"

# ------------------------------------------------------------------------------
# Nginx Ingress Setup
# ------------------------------------------------------------------------------

# This will also set up a load balancer on the DigitalOcean account.
helm upgrade --install nginx-ingress --wait --namespace nginx-ingress stable/nginx-ingress > /dev/null 2>&1 & \
spinner "Installing Nginx Ingress"

echo -e "\033[32mNginx Ingress is ready.\033[39m"
