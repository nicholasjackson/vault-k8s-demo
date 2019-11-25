## Create K8s cluster and install vault

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

## Set env vars to use vault locally

```
export VAULT_HTTP_ADDR=http://localhost:8200
export VAULT_TOKEN=root
```

## Configure Vault K8s integration

```shell
➜ vault auth enable kubernetes

Success! Enabled kubernetes auth method at: kubernetes/

```

## Fetch the ca.crt

```
export TOKEN_NAME=$(kubectl get serviceaccount/vault -o jsonpath='{.secrets[0].name}')

kubectl get secret $TOKEN_NAME -o jsonpath='{.data.ca\.crt}' | base64 -d
```

## Write the config

```
➜ vault write auth/kubernetes/config \
    token_reviewer_jwt="$(kubectl get secret $TOKEN_NAME -o jsonpath='{.data.token}' | base64 -d)" \
    kubernetes_host="https://kubernetes:443" \
    kubernetes_ca_cert=@ca.crt
```

## Configure access for app-a service account

```
➜ vault policy write app-a ./app-policy.hcl

Success! Uploaded policy: app-a
```

```
vault write auth/kubernetes/role/app-a \
    bound_service_account_names=app-a \
    bound_service_account_namespaces=default \
    policies=app-a \
    ttl=1h
```

## Write the secret

```
➜ vault kv put secret/app_a username=myuser password=mypassword
Key              Value
---              -----
created_time     2019-11-25T12:32:17.240627Z
deletion_time    n/a
destroyed        false
version          1
```

## Run the app

```
kubectl apply -f ./app.yml
```

## Check the secrets have been rendered

```
➜ kubectl exec -it vault-demo cat /etc/secrets/secrets.json
{
  api: {

    username: "myuser"
    password: "mypassword"
  }
}
```
