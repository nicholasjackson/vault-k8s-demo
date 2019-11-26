#!/bin/sh

# Enable the K8s auth mount
vault auth enable kubernetes

# Fetch the name of the token for the Vault service account
export TOKEN_NAME=$(kubectl get serviceaccount/vault -o jsonpath='{.secrets[0].name}')

# Write the CA used to access the K8s API
kubectl get secret $TOKEN_NAME -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

# Write the configuration for the auth mount
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(kubectl get secret $TOKEN_NAME -o jsonpath='{.data.token}' | base64 -d)" \
    kubernetes_host="https://kubernetes:443" \
    kubernetes_ca_cert=@ca.crt

# Write the secret
vault kv put secret/app_a username=myuser password=mypassword

# Write the policy
vault policy write app-a ./app-policy.hcl

# Create the role
vault write auth/kubernetes/role/app-a \
    bound_service_account_names=app-a \
    bound_service_account_namespaces=default \
    policies=app-a \
    ttl=1h