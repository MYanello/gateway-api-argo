# gateway-api-argo

### Requirements
## 1. Setup argo kubectl plugin: 

See: https://argoproj.github.io/argo-rollouts/features/kubectl-plugin/ 

```
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64

chmod +x ./kubectl-argo-rollouts-darwin-amd64

sudo mv ./kubectl-argo-rollouts-darwin-amd64 /usr/local/bin/kubectl-argo-rollouts
```

Check it's installed:
```
kubectl argo rollouts version
```

## 2. Setup k3s cluster

./setup-env.sh

## 3. Install Gateway APIs

```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

## 4. Install argo 

Create namespace:

```
kubectl create namespace argo-rollouts
```

Apply config crds:
```
kubectl apply -k https://github.com/argoproj/argo-rollouts/manifests/crds\?ref\=v1.7.2
```

```
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/download/v1.7.2/install.yaml
```

Create ClusterRole for K8s Gateway plugin

```
kubectl apply -f argo/gw-clusterrole.yaml
```

Restart

```
kubectl rollout restart deployment -n argo-rollouts argo-rollouts
```

## 5. Pick a gateway! 

### Envoy Gateway

```
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.1.2 -n envoy-gateway-system --create-namespace

```


```
kubectl apply -f gateways/envoy/gateway.yaml 
```

### Istio Ambient

```
istioctl install --set profile=ambient
```

```
kubectl apply -f gateways/istio-ambient/gateway.yaml
```

### Istio Mesh 

```
istioctl install --set profile=minimal
```

### Gloo Gateway 

https://docs.solo.io/gateway/main/quickstart/

## glooctl

1. Install glooctl
```
curl -sL https://run.solo.io/gloo/install | sh
export PATH=$HOME/.gloo/bin:$PATH
```

2. Install via glooctl
```
glooctl install gateway --values - << EOF
discovery:
  enabled: false
gatewayProxies:
  gatewayProxy:
    disabled: true
gloo:
  disableLeaderElection: true
kubeGateway:
  enabled: true
EOF 
```

## helm

1. Add helm repo
```
helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update
```

2. Install via helm
```
helm install gloo gloo/gloo --namespace gloo-system --create-namespace -f -<<EOF
discovery:
  enabled: false
gatewayProxies:
  gatewayProxy:
    disabled: true
gloo:
  disableLeaderElection: true
kubeGateway:
  enabled: true
EOF
```

### NGNIX Fabric 

```
helm install ngf oci://ghcr.io/nginxinc/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway
```

4. Allow Argo Rollouts to edit Http Routes

```
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gateway-controller-role
  namespace: argo-rollouts
rules:
  - apiGroups:
      - gateway.networking.k8s.io
    resources:
      - httproutes
    verbs:
      - get
      - patch
      - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gateway-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gateway-controller-role
subjects:
  - namespace: argo-rollouts
    kind: ServiceAccount
    name: argo-rollouts

```

## 6. Create a Gateway

```
kubectl apply -f gateways/<provider>/gateway.yaml
```

## 7. Apply sample apps 

```
kubectl apply -f example_apps/svc.yaml
```

## 8. Create an HTTPRoute

```
kubectl apply -f gateways/<provider>/httproute.yaml
```

## 9. Perform a Canary

```
kubectl apply -f argo/rollout-blue.yaml
```

```
kubectl argo rollouts get rollout rollouts-demo
```

```
kubectl argo rollouts promote rollouts-demo
```

Now switch to yellow:
```
kubectl apply -f argo/rollout-yellow.yaml
```

```
kubectl argo rollouts get rollout rollouts-demo
```

Check the HTTPRoute:
```
kubectl get httproute -o yaml
```

```
kubectl argo rollouts promote rollouts-demo
```

## 10. View in Argo Rollouts Demo UI

```
kubectl port-forward -n <gw-ns> service/<gw-svc> 8888:80 &
```


For example:
```
kubectl port-forward service/envoy-default-gw-3d45476e 8888:80 -n envoy-gateway-system &


kubectl port-forward service/gloo-proxy-http 8888:8080 & 

kubectl port-forward service/ngf-nginx-gateway-fabric 8888:80 -n nginx-gateway &

kubectl port-forward services/gw-istio -n default 8888:80
```


View Argo's dashboard:
```
kubectl argo rollouts dashboard
```