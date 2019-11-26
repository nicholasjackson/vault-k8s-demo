# HashiCorp Vault on Kubernetes Example
The repository shows how to use HashiCorp Vault with a Kubernetes application. This repo uses [Shipyard](https://shipyard.demo.gs) to create a development Kubernetes cluster with Vault installed in your local Docker environment. All techniques and config will also work on a production cluster.

## Requirements
* Docker
* Shipyard [https://shipyard.demo.gs](https://shipyard.demo.gs)
* Kubectl (optional)
* Vault CLI (optional) [https://releases.hashicorp.com/vault/1.3.0/](https://releases.hashicorp.com/vault/1.3.0/)

## Process
To access secrets in HashiCorp Vault the user or application authenticates with Vault and obtains an Access Token, the Access Token has policy applied to it which determines the operations and secrets the user can access in Vault.

[https://www.vaultproject.io/docs/concepts/policies.html](https://www.vaultproject.io/docs/concepts/policies.html)

When working with Kubernetes, Service Accounts Tokens can be used to authenticate with Vault and gain access to secrets.

To simplify the process of Authentication and managing the lifecycle of a Vault Token `vault agent` is used. Vault agent automatically uses the Pod Service Account Token to login to Vault and obtain a Vault Token. This token is then securly stored in memory and the Vault API is exposed to applications in the pod via localhost. 

[https://www.vaultproject.io/docs/agent/caching/index.html](https://www.vaultproject.io/docs/agent/caching/index.html)

To provide secrets to the application we can use templates with `vault agent`, this allows you to transform the secrets in Vault to static files which can be read by your application.

[https://www.vaultproject.io/docs/agent/template/index.html](https://www.vaultproject.io/docs/agent/template/index.html)

This repository shows how all this can be achieved, you will see how to:

1. Configure the Vault authentication backend for your Kubernetes cluster
2. Grant access to Vault secrets based on service account
3. How to use `vault agent` as a sidecar application in your pods for automatic authentication
4. How to use templates to write secrets as application configuration files

## Create a K8s cluster and install Vault

In order to follow this tutorial you need a Vault cluster and a Kubernetes cluster, you can use `Shipyard` to create a local dev version which is perfect for trialing new techniques. Shipyard can be installed from the following URL [https://shipyard.demo.gs](https://shipyard.demo.gs) .

Once you have Shipyard installed you can use the simple command line to spin up a Kubernetes cluster in Docker. Shipyard will automatically install Vault using the [Helm chart](https://github.com/hashicorp/vault-helm) with default values suitable for a dev cluster.

We are going to run Vault in `dev` mode which will use an in-memory database, and in order to use the Kubernetes authentication method we need to grant Vault permissions to validate Service Account Tokens. This is requires RBAC for the Service Account which Vault runs in. The Helm config `authDelegator` can automatically configure this for you.

```yaml
server:
  dataStorage:
    size: 512Mb
  dev:
    enabled: true # Run in dev mode
  standalone:
    enabled: true # Run standalone with built in storage
  authDelegator:
    enabled: true # Enable Kubernetes authentication
ui:
  enabled: true # Enable the UI
```

To create the cluster run the following command:

```
➜ yard up --enable-vault true

     _______. __    __   __  .______   ____    ____  ___      .______       _______
    /       ||  |  |  | |  | |   _  \  \   \  /   / /   \     |   _  \     |       \
   |   (----`|  |__|  | |  | |  |_)  |  \   \/   / /  ^  \    |  |_)  |    |  .--.  |
    \   \    |   __   | |  | |   ___/    \_    _/ /  /_\  \   |      /     |  |  |  |
.----)   |   |  |  |  | |  | |  |          |  |  /  _____  \  |  |\  \----.|  .--.  |
|_______/    |__|  |__| |__| | _|          |__| /__/     \__\ | _| `._____||_______/


Version: 0.5.4

## Creating K8s cluster in Docker and installing Consul

### Creating Kubernetes cluster, this process will take approximately 2 minutes
#### Create Kubernetes cluster in Docker using K3s
#### Waiting for Kubernetes to start
#### Install Kubernetes dashboard and Local storage controller
#### Installing Consul using latest Helm chart
##### Waiting for Consul server to start
##### Waiting for Consul client to start
#### Installing Vault using latest Helm chart
##### Waiting for Consul server to start

### Setup complete:

To interact with Kubernetes set your KUBECONFIG environment variable
export KUBECONFIG="$HOME/.shipyard/yards/shipyard/kubeconfig.yml"

Consul can be accessed at: http://localhost:8500
Vault can be accessed at: http://localhost:8200
  Token: root
Kubernetes dashboard can be accessed at: http://localhost:8443

To expose Kubernetes pods or services use the 'yard expose' command. e.g.
yard expose --service-name svc/myservice --port 8080:8080

When finished use "yard down" to cleanup and remove resources
```

Shipyard will create a Kubernetes cluster locally in Docker with Vault installed. Vault is exposed to http://localhost:8200 enabling the Vault CLI or API access from your local machine. The Kubernetes dashboard is available at http://localhost:8443.

**Vault Token = root**

## Set environment variables to use Vault locally (optional)

If you plan to interact with the Vault and Kubernetes cluster using your local machine you can export the following environment variables.

```shell
export KUBECONFIG="$HOME/.shipyard/yards/shipyard/kubeconfig.yml"
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root
```

## Interacting with Vault using the Shipyard interactive shell (optional)

If you do not have Kubectl or Vault CLI installed you can use the Shipyard interactive shell with the command `yard tools`. The shipyard tools will start a Docker container with everything installed and configured. Your current folder will automatically be mapped into the container so any changes to files you make will be saved.

```shell
➜ yard tools

     _______. __    __   __  .______   ____    ____  ___      .______       _______
    /       ||  |  |  | |  | |   _  \  \   \  /   / /   \     |   _  \     |       \
   |   (----`|  |__|  | |  | |  |_)  |  \   \/   / /  ^  \    |  |_)  |    |  .--.  |
    \   \    |   __   | |  | |   ___/    \_    _/ /  /_\  \   |      /     |  |  |  |
.----)   |   |  |  |  | |  | |  |          |  |  /  _____  \  |  |\  \----.|  .--.  |
|_______/    |__|  |__| |__| | _|          |__| /__/     \__\ | _| `._____||_______/


Version: 0.5.4

## Running tools container

To expose service in Kubernetes to localhost use:
port forwarding e.g.

kubectl port-forward --address 0.0.0.0 svc/myservice 10000:80

Mapping ports 10000-10100 on localhost to
10000-10100 on container.

Linking container --network k3d-shipyard
Setting environment -e CONSUL_HTTP_ADDR=http://k3d-shipyard-server:30443
Setting environment -e VAULT_ADDR=http://k3d-shipyard-server:30445 -e VAULT_TOKEN=root


root@2b277b98fe13:/work#
```

## Checking your install

Once everything is up and running you will see the Vault server running as a Kubernetes pod, the Helm chart takes care of this installation and setting up any specifics such as Kubernetes services.

```shell
➜ kubectl get pods
NAME                                                              READY   STATUS    RESTARTS   AGE
consul-consul-connect-injector-webhook-deployment-9479cfddgh4v6   1/1     Running   0          9m27s
consul-consul-server-0                                            1/1     Running   0          9m26s
consul-consul-tsq4w                                               1/1     Running   0          9m27s
vault-0                                                           1/1     Running   0          8m54s
```

Shipyard makes Vault accessible to you at `http://localhost:8200`, you can use the Vault CLI to query the status.

```shell
➜ vault status
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.3.0
Cluster Name    vault-cluster-582c15fd
Cluster ID      c680bf15-d86f-28cc-196a-18d625985f48
HA Enabled      false
```

## Configure Vault K8s integration

[https://www.vaultproject.io/docs/auth/kubernetes.html](https://www.vaultproject.io/docs/auth/kubernetes.html)

Once Vault and Kubernetes are running we need to perform a one time setup to allow Vault to use the Kubernetes API. First we need to enable the backend in Vault.

```shell
➜ vault auth enable kubernetes

Success! Enabled kubernetes auth method at: kubernetes/

```

The backend then needs to be configured, to configure the backend we need to provide it with:

* The location of the Kubernetes server
* A valid JWT which can be used to access the K8s API server
* The CA used by the API server to secure it with SSL

### Fetching the ca.crt

When you install Vault using the K8s Helm chart a service account called `vault` is created, this service account has the correct permissions to access the K8s API server in order to validate tokens. We can get the token name using the following `kubectl` command. This will store the token name in an environment variable for later use.

```shell
export TOKEN_NAME=$(kubectl get serviceaccount/vault -o jsonpath='{.secrets[0].name}')
```

Once we have the token name we can obtain the Certificate Authority from the Service Account secret. The following command obtains the CA and writes it to a file `ca.crt`.

```shell
kubectl get secret $TOKEN_NAME -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
```

The final step is to configure the Authentication backend, you do this by writing parameters to the configuration path. We are going to set the `token_reviewer_jwt` which is a K8s JWT with access to the API server. The `kubernetes_host`, since we are running Vault on Kubernetes we can use the K8s service which the helm chart creates for us. And finally we store the Kubernetes CA in order to validate the connection to the Kubernetes API.

The token can be obtained using a similar process you used to obtain the API server certificate. This time we are getting the token.

```shell
kubectl get secret $TOKEN_NAME -o jsonpath='{.data.token}' | base64 -d)
```

Putting all of this together we can use the following command:

```
➜ vault write auth/kubernetes/config \
    token_reviewer_jwt="$(kubectl get secret $TOKEN_NAME -o jsonpath='{.data.token}' | base64 -d)" \
    kubernetes_host="https://kubernetes:443" \
    kubernetes_ca_cert=@ca.crt
Success! Data written to: auth/kubernetes/config
```

## Accessing Vault secrets from Kubernetes Pods

Now the authentication backend has been created you can create a secret and policy which grants access to that secret. First let's create a secret with two parameters username and password.

```
➜ vault kv put secret/app_a username=myuser password=mypassword
Key              Value
---              -----
created_time     2019-11-25T12:32:17.240627Z
deletion_time    n/a
destroyed        false
version          1
```

You can then create a policy which allows read access to this secret

```
path "secret/data/app_a" {
  capabilities = ["read"] 
}
```

For convenience this file has already been created in `app-policy.hcl`, you can write this to Vault using the following command.

```
➜ vault policy write app-a ./app-policy.hcl

Success! Uploaded policy: app-a
```

### Mapping Vault policy to Kubernetes Service Accounts

The token created with a Kubernetes Service account is a cryptographically verifiable JWT, Vault can use this token and validate it with the K8s API ensuring the identity of the pod. In order to gain access to Vault secrets a Vault Token still needs to be used. The `vault agent` will exchange the Service Account Token allocated to the pod for a Vault token which has policy attached to it. In order to associate policy with a Kubernetes service account we create a role. This is the mapping between Vault and Kubernetes.

```
vault write auth/kubernetes/role/app-a \
    bound_service_account_names=app-a \
    bound_service_account_namespaces=default \
    policies=app-a \
    ttl=1h
```

A pod which has the Service Account `app-a` can authenticate with Vault and obtain a token which has the `app-a` policy attached to it. This policy allows access to the secrets stored at `secret/data/app_a`.

## Configuring Vault Agent as a Sidecar

To access secrets you will use Vault Agent as a sidecar process in your Pod. Vault Agent will automatically authenticate with Vault using the Service Account allocated to the Pod. To configure Vault Agent we need to provide it a configuration file which contains a number of different `stanza`. The first element is authentication.

[https://www.vaultproject.io/docs/agent/autoauth/index.html](https://www.vaultproject.io/docs/agent/autoauth/index.html)

The first stanza you are going to configure is the location to the vault server. Since we configured Vault to run on our Kubernetes cluster using the Helm chart, the service `vault` is automatically created for you. When configuring the location of the Vault server for the Agent you can use this service.  If Vault was not running inside the K8s server this address could be any accessible URI for your Vault server.

```ruby
vault {
  address = "http://vault:8200"
}
```

Next we need to define the authentication configuration. The `auto_auth` stanza defines which auth method Vault Agent is going to use, we are going to configure the `kubernetes` authentication method which is mounted at the path `auth/kubernetes`. You configured this earlier in this guide. We also need to define which role will be used. In the previous step we configured the role `app-a` which was linked to the service account `app-a`.  When the Vault Agent runs it will pick up the default service account attached to the Pod and use the token to obtain a Vault token. Assuming the name of the Service Account matches the one in the `bound_service_account_names` for the role config. Vault will return a token which has the policy `app-a` attached.

```ruby
auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "app-a"
    }
  }
}
```

Vault agent can be configured to write the token to a file or the token can be retained in memory and the Agent can act as a transparent proxy to the Vault server and will authenticate requests automatically using the current token. `use_auto_auth_token` will cache the token in memory and automatically forwards this with a request to the Vault API. The `listener` stanza makes the Vault API available at the defined `address`, in this instance localhost with tls diasbled. Technically for the purpose of this demo this stanza is not required, however it is interesting to see how this could be used.

```ruby
cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = true
}
```

Finally we can configure Vault Agent to process a template for us, we can define a template using the Consul Template markup language. This template can be used to extract secrets from Vault and write them to an application specific configuration file. For example the following template could be defined which would write the secret values for `username` and `password` into a JSON format file.

```json
{
  api: {
    {{ with secret "secret/app_a" }}
    username: "{{ .Data.data.username }}"
    password: "{{ .Data.data.password }}"{{ end }}
  }
}
```

[https://www.vaultproject.io/docs/agent/template/index.html](https://www.vaultproject.io/docs/agent/template/index.html)

This feature is configured with the following stanza, specifying the source template and the destination to write the processed output to. Vault agent will track the lifecycle of the secret automatically, should the value of a secret defined in the template change then the template will automatically be re-processed.

```
template {
  source      = "/etc/vault/template.ctmpl"
  destination = "/etc/secrets/secrets.json"
}
```

Putting this all together we get:

```ruby
vault {
  address = "http://vault:8200"
}

auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "app-a"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = true
}

template {
  source      = "/etc/vault/template.ctmpl"
  destination = "/etc/secrets/secrets.json"
}
```

## Creating the Kubernetes Config

The first thing we need to create is the config map which contains our template and configuration file for Vault Agent. A simple ConfigMap is perfect for this purpose.


```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: default
data:
  template.ctmpl: |-
    {
      api: {
        {{ with secret "secret/app_a" }}
        username: "{{ .Data.data.username }}"
        password: "{{ .Data.data.password }}"{{ end }}
      }
    }
  agent-config.hcl: |-
    auto_auth {
      method "kubernetes" {
        mount_path = "auth/kubernetes"
        config = {
          role = "app-a"
        }
      }
    }
    # ...
```

You then need to create a service account, remember from the Vault authentication section, Vault Agent is going to exchange the Service Account Token for a Vault Token in order to retrieve secrets. The name of this service account must have the same name as the service account defined in the role. 

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-a
automountServiceAccountToken: true
```

Finally we can define out pod spec, there is nothing unusual here, we are defining two Kubernetes volumes, one for the configuration and template, and one where the secrets will be written to.

```yaml
volumes:
- name: secrets
  emptyDir: {}
- name: config-volume-agent
  configMap:
    name: vault-config
    items:
    - key: agent-config.hcl
      path: agent-config.hcl
    - key: template.ctmpl
      path: template.ctmpl
```

We mount these into the Vault Agent container at the following locations:

```yaml
volumeMounts:
- name: config-volume-agent
  mountPath: /etc/vault
  readOnly: true
- name: secrets
  mountPath: /etc/secrets
```

Running Vault Agent as a sidecar process is quite straight forward. Agent is a subcommand from the main Vault binary. We only need to set a single flag with the location for our configuration file.

```
image: vault:1.3.0
command: ["vault"]
args: ["agent", "-config=/etc/vault/agent-config.hcl"]
```

Putting this all together we get the following Pod specification.

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: vault-demo
spec:
  serviceAccountName: app-a
  containers:
  - name: vault-agent
    image: vault:1.3.0
    command: ["vault"]
    args: ["agent", "-config=/etc/vault/agent-config.hcl"]
    volumeMounts:
    - name: config-volume-agent
      mountPath: /etc/vault
      readOnly: true
    - name: secrets
      mountPath: /etc/secrets
  volumes:
  - name: secrets
    emptyDir: {}
  - name: config-volume-agent
    configMap:
      name: vault-config
      items:
      - key: agent-config.hcl
        path: agent-config.hcl
      - key: template.ctmpl
        path: template.ctmpl
```

## Running the app

Now everything is configured we can run the application using kubectl, which will launch Vault agent as a sidecar. When the agent starts it will automatically authenticate with Vault and retrieve the secrets defined in the template.  Deploy the application using the following command.

```shell
kubectl apply -f ./app.yml
```

## Check the secrets have been rendered
Once the application is up and running you can double check that the secrets have been correctly rendered using the following command. You should see the output of your template with the secrets you stored in Vault.

```
➜ kubectl exec -it vault-demo cat /etc/secrets/secrets.json
{
  api: {

    username: "myuser"
    password: "mypassword"
  }
}
```

## Summary

In this short demo you have learned how to configure Vault to provide secrets to Kubernetes. This demo only looked at statics secrets, however; Vault is capable of way more than a drop in replacement for Kubernetes secrets. Check out the Vault documentation for more information on the other types of secrets which can be stored with Vault.

[https://www.vaultproject.io/docs/secrets/index.html](https://www.vaultproject.io/docs/secrets/index.html)