# Lordran-Dev

### Table of Contents

- [About This Repository](#about-this-repository)
- [Initial Configuration](#initial-configuration)
- [Spinning A Cluster From Scratch](#spinning-a-cluster-from-scratch)
- [Recovering A Cluster](#recovering-a-cluster)
- [Kubeseal](#kubeseal)
      - [Installing Kubeseal](#installing-kubeseal)
      - [Using Kubeseal To Encrypt Secrets](#using-kubeseal-to-encrypt-secrets)
      - [DigitalOcean Kubeconfig File](#digitalocean-kubeconfig-file)
- [Adding Applications](#adding-applications)
- [Config Map Hash](#config-map-hashs)
- [TODO](#todo)

## About This Repository

This is a repository used to reflect a Kubernetes configuration state for a development environment. The configuration in this repository is deployed automatically via the Flux controller running on the cluster. This follows the GitOps convention where the cluster's desired state is stored in Git and can be easily recreated in the event of failure.

## Initial Configuration

The base configuration for this cluster requires certain components to be installed and/or set up prior to Flux picking up the repository and applying the current state. These components include:

* Helm and Tiller
* Nginx Ingress (with Load Balancer)
* DNS 'A' record pointing to the DigitalOcean LoadBalancer
* Sealed Secrets
* Cert Manager
* Flux

**Helm and Tiller** are required for installing and managing applications deployed to the cluster. This is also how the majority of applications will be deployed via Flux as well.

The **Nginx Ingress** is required for interfacing public access to applications running on the cluster. The Ingress will also spin up a DigitalOcean Load Balancer by association. It is important to note that this is currently the *only* way DigitalOcean will allow the Ingress to be mapped to the Load Balancer. An existing Load Balancer *cannot* be assigned to the Ingress of a cluster manually. A new Load Balancer *must* be created by the Ingress at the time the cluster is created.

A **DNS 'A' record** must be mapped to the Load Balancer prior to the cluster initialization, else the TLS certificates for all public facing applications will fail to install properly.

**Sealed Secrets** is an application that runs on the cluster handling the decryption of secrets that are stored on said cluster. The secrets must be encrypted locally with kubeseal before they are applied to the cluster. Encrypting secrets this way and decoding them on the cluster allows the secrets to be committed into a repository without the fear of exposing sensitive information. If recovering a previous cluster, the existing private key from the previous cluster must be restored to the new cluster before any previously encrypted secrets can be decrypted.

**Cert Manager** takes care of the TLS certificates needed for HTTPS traffic. It automates the process of retrieving the certificates and keeping them up to date throughout the lifecycle of the application. It is required that Cert Manager be installed on the cluster before Flux, else the controllers may not be ready in time to fetch certificates for applications that are spun up during the initial Flux scan.

**Flux** is what is used to wrap everything together and maintain the cluster's state. Flux will monitor a given repository for changes. Whenever a change is detected, Flux will apply the change to the cluster automatically in a matter of minutes.

## Spinning A Cluster From Scratch

If a Kubernetes cluster has not been created, the setup script located at `setup/init-cluster.sh` can take care of the creation for you. It will also guide you through setting up the other components required for Flux's initial scan of the repository.

## Recovering A Cluster

If a Kubernetes cluster has been previously created and needs to be recovered as a new cluster, most of the steps will be the same. The main difference is that the private key used by Sealed Secrets will need to be restored. If the private key is not restored, previously encrypted secrets will not be able to be decrypted on the cluster and will need to be re-encrypted with the new private key.

To back up an existing key, run the following command:

```
kubectl get secret -n kube-system sealed-secrets-key -o yaml > master.key
```

This will save the secret information into a YAML formatted file.

To restore the private key, simply apply the configuration to the cluster as you would any other Kubernetes resource:

```
kubectl apply -f master.key
```

**Note**: This will need to be done *before* the Sealed Secrets controller is installed onto the cluster. If the Sealed Secrets controller is already present on the cluster, the command will need to `replace` the existing configuration rather than `apply` a new one.

## Kubeseal

Kubeseal is the client side tool used to encrypt secrets for Sealed Secrets and is in a bit of a funky state at the time of writing. The latest version will not encrypt anything aside form `Opaque` secrets properly. This means that in order to encrypt things such as Docker credentials, version 0.5.1 will need to be used. Anything else should be encrypted with version 0.7.0 as there are file structure changes that need to be followed. There is also an issue with DigitalOcean supplied kubeconfig files as well.

##### Installing Kubeseal

To install version 0.5.1 run the following command:

```
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.5.1/kubeseal-darwin-amd64

sudo install -m 755 kubeseal-darwin-amd64 /usr/local/bin/kubeseal51
```

For version 0.7.0 run this one:

```
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.7.0/kubeseal-darwin-amd64

sudo install -m 755 kubeseal-darwin-amd64 /usr/local/bin/kubeseal7
```

##### Using Kubeseal To Encrypt Secrets

Encrypting secrets must be done on the client machine before committing the secret to the Git repository. The client tool must have access to either the cluster where the Sealed Secrets controller is running, or the public key that belongs to the controller.

To encrypt a secret, simply create a secret to the standard Kubernetes spec *without* applying it to the cluster. Once this secret file has been created, it can be encrypted using Kubeseal. Here's an example of how to encrypt Docker login credentials:

```
kubectl create secret docker-registry regcred --docker-server=https://example.registry.com/ --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_EMAIL --dry-run -o json > regcred.json
```

Notice the `--dry-run` flag on the command. This will ensure that the resource is *not* applied to the cluster. Instead of applying the secret configuration to the cluster it is redirected to a file named `regcred.json`. Before it is applied to the cluster, it should be encrypted with the following command:

```
kubeseal51 --controller-name=sealed-secrets --format yaml < regcred.json > regcred.yaml
```

Or if using the local public key:

```
kubeseal51 --cert=/path/to/public-key.pem --controller-name=sealed-secrets --format yaml < regcred.json > regcred.yaml
```

Once the `regcred.yaml` file is generated, it may be committed into the Git repository safely without the fear of exposing sensitive information. An encrypted version of the secret should look something like the following:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: regcred
spec:
  data: some-super-long-encrypted-string
```

These secrets can be referenced in the same way as the Kubernetes standard secrets. Before Kubernetes picks up the secret, Sealed Secrets will automatically handle decrypting the configuration before feeding it to the target resource.

##### DigitalOcean Kubeconfig File

DigitalOcean handles credentials in a unique way when it comes to Kubernetes. When creating a cluster via the command line, or when saving the cluster's credentials via the command line, the format they are saved in is **incompatible** with Kubeseal. In order to use Kubeseal with a DigitalOcean kubeconfig, the config must be either downloaded from the control panel, or copied from the terminal with the `show` command in `doctl`. Here's a quick reference chart.

| Method                                     | Compatibility |
| :----------------------------------------- | :------------ |
| Auto saved from cluster creation           | INCOMPATIBLE  |
| `doctl kubernetes cluster kubeconfig save` | INCOMPATIBLE  |
| `doctl kubernetes cluster kubeconfig show` | COMPATIBLE    |
| Download via DigitalOcean control panel    | COMPATIBLE    |

## Adding Applications

When adding an application, there are a couple of different resources to take into consideration.

* Namespace
* Release Configuration
* Helm Chart
* Config Map
* Secrets
* Registry Credentials

The **Namespace** and **Release Configuration** are the minimum requirements for a traditional application release. If releasing an application via Helm, it may be a good idea to store sensitive information is either a **Config Map** or a **Secrets** resource. Likewise, if spinning up a Helm release via a custom **Helm Chart**, you'll want to make sure it is present in the repository. When accessing private Docker registries, make sure to include any **Registry Credentials** that are needed.

## Config Map Hash

When deploying applications to a cluster, it is often desirable to use config maps to store non-sensitive configuration info for the application. The problem is that when this config map is updated, the application's deployment is not triggered and the pods will not pick up the new config map values. In order for the deployment to refresh and deploy new pods, an aspect of the `spec` key needs to change.

We can leverage an annotation to handle this. Let's walk through an example. Say we have the following config map that we want to tie to an application.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-application-config
  namespace: demo
data:
  APP_NAME: "my-application"
  APP_ENVIRONMENT: "staging"
```

A simplified deployment could look like this:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-application
  namespace: demo
  labels:
    app: my-application
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-application
  template:
    metadata:
      labels:
        app: my-appliction
      annotations:
        # This is where we will store our config map hash.
        configHash: ""
    spec:
      containers:
      - name: my-application
        image: my-application-image
        ports:
        - containerPort: 80
        # Import the values from the config map.
        envFrom:
        - configMapRef:
            name: my-application-config
        env:
          # Use the config map hash as an environment variable.
          # Whenever the config hash is updated the deployment will refresh, ensuring the pods get the most recent configuration.
          - name: CONFIG_HASH
            valueFrom:
              fieldRef:
                fieldPath: spec.template.metadata.annotations.configHash
```

We can use a `sha256` hash to tie this deployment to a specific version of our config map. Because of the way `sha256` hashes work, the output of the hash will only change if the content of our config map changes. The hash will need to be generated on the client side using the following command:

```
cat /path/to/config-map.yaml | sha256sum | head -c 64
```

In this case, the config map hash will be:

```
20caf2a2848576f4085e63678325eeb7da36dd5c00befe2e4ce1d85312ed0ca3
```

This can be placed into the `spec.template.metadata.annotations.configHash` key on the deployment configuration. If the config map needs to be updated, a new hash will need to be generated from the updated file. Using this method, a deployment will always reference a specific version of a config map and the pods will redeploy with the new configuration when a change is detected.

## TODO

* Update dependency check to check for updates to the tools which are already installed.
* Add `coreutils` to the dependency check for the use of `sha256sum`.
* Rename `sealed-secrets` release to `sealed-secrets-controller` so that a flag doesn't need to be specified for the encryption stage.
* Move Helm charts to individual repositories.