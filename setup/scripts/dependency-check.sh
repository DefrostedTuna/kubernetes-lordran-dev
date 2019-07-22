#!/bin/bash

# ------------------------------------------------------------------------------
# Dependency Check
# ------------------------------------------------------------------------------

echo "Checking dependencies..."

# Install Homebrew.
if [ -z $(command -v brew) ]; then
  echo -e "\033[31mHomebrew was not found.\033[39m"
  echo "Installing Homebrew, please wait..."

  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

  # Double check that Homebrew was successfully installed.
  # If it was not installed properly, we do not want to continue the script.
  if [ -z $(command -v brew) ]; then
    echo -e "\033[31mThere was an error installing Homebrew." \
            "Homebrew is required to install the remaining dependencies.\033[39m"
    exit 1
  fi
else
  echo -e "\033[32mHomebrew is already installed!\033[39m"
fi

# Install Kubectl.
if [ -z $(command -v kubectl) ]; then
  echo -e "\033[31mKubectl was not found.\033[39m"
  echo "Installing Kubectl, please wait..."

  brew install kubernetes-cli

  # Double check that Kubectl was successfully installed.
  if [ -z $(command -v kubectl) ]; then
    echo -e "\033[31mThere was an error installing Kubectl. Kubectl is" \
            "required to connect to the Kubernetes cluster.\033[39m"
    exit 1
  fi
else
  echo -e "\033[32mKubectl is already installed!\033[39m"
fi

# Install Helm.
if [ -z $(command -v helm) ]; then
  echo -e "\033[31mHelm was not found.\033[39m"
  echo -e "Installing Helm, please wait..."

  brew install kubernetes-helm

  # Double check that Helm was successfully installed.
  if [ -z $(command -v helm) ]; then
    echo -e "\033[31mThere was an error installing Helm. Helm is required to" \
            "install software to the Kubernetes cluster.\033[39m"
    exit 1
  fi
else
  echo -e "\033[32mHelm is already installed!\033[39m"
fi

# Install Wget.
if [ -z $(command -v wget) ]; then
  echo -e "\033[31mWget was not found.\033[39m"
  echo "Installing wget, please wait..."

  brew install wget

  # Double check that Homebrew was successfully installed.
  # If it was not installed properly, we do not want to continue the script.
  if [ -z $(command -v wget) ]; then
    echo -e "\033[31mThere was an error installing wget." \
            "Wget is required to fetch Kubeseal.\033[39m"
    exit 1
  fi
else
  echo -e "\033[32mWget is already installed!\033[39m"
fi

# Install Kubeseal51
if [[ -z $(command -v kubeseal51) ]]; then
  echo -e "\033[31mKubeseal v0.5.1 was not found.\033[39m"

  echo "Fetching kubeseal v0.5.1, please wait..."
  wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.5.1/kubeseal-darwin-amd64 -O kubeseal-0.5.1 > /dev/null 2>&1

  echo "Installing kubeseal v0.5.1 to /usr/local/bin/kubeseal51"
  echo "If promtpted, please enter your admin password to finish this process."
  sudo install -m 755 kubeseal-0.5.1 /usr/local/bin/kubeseal51
else
  echo -e "\033[32mKubeseal v0.5.1 is already installed!\033[39m"
fi

# Install Kubeseal7
if [[ -z $(command -v kubeseal7) ]]; then
  echo -e "\033[31mKubeseal v0.7.0 was not found.\033[39m"

  echo "Fetching kubeseal v0.7.0, please wait..."
  wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.7.0/kubeseal-darwin-amd64 -O kubeseal-0.7.0 > /dev/null 2>&1

  echo "Installing kubeseal v0.7.0 to /usr/local/bin/kubeseal7"
  echo "If promtpted, please enter your admin password to finish this process."
  sudo install -m 755 kubeseal-0.7.0 /usr/local/bin/kubeseal7
else
  echo -e "\033[32mKubeseal v0.7.0 is already installed!\033[39m"
fi

# Install Doctl.
if [ -z $(command -v doctl) ]; then
  echo -e "\033[31mDoctl was not found.\033[39m"
  echo -e "Installing Doctl, please wait..."

  brew install doctl

  # Double check that Doctl was successfully installed.
  if [ -z $(command -v doctl) ]; then
    echo -e "\033[31mThere was an error installing Doctl." \
            "Doctl is required to interact with DigitalOcean.\033[39m"
    exit 1
  fi
else
  echo -e "\033[32mDoctl is already installed!\033[39m"
fi

if [[ -z $(doctl auth init 2>/dev/null | grep "Validating token... OK") ]]; then
  echo -e "\033[31mAn access token for doctl was not found.\033[39m"
  echo "In order to interact with DigitalOcean, doctl must authenticate using an access token."
  echo "This token can be created via the Applicatons & API section of the DigitalOcean Control Panel."
  echo "https://cloud.digitalocean.com/account/api/tokens"
  echo "Please note that this token must have both read and write access."
  echo

  while true; do
    echo -e "\033[33mPlease provide your DigitalOcean API Token\033[39m: "
    read DO_TOKEN

    doctl auth init -t "${DO_TOKEN}" > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
      echo "\033[32mToken is valid! Doctl can now communicate with DigitalOcean!\033[39m"
      break
    else
      echo -e "\033[31mThere was an error authenticating with DigitalOcean. Please try again.\033[39m"
    fi
  done
fi
echo