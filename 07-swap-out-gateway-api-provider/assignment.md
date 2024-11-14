## Pick a provider

Choose one of the following providers to install an API Gateway in the cluster.

> This is only a subset of the supported API Gateway providers. You can find the full list [here](https://gateway-api.sigs.k8s.io/implementations/), or check out the [Argo Rollouts Gateway API plugins examples](https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi) if you want to try another provider on your own!

### Gloo Gateway
===============

[Gloo Gateway](https://docs.solo.io/gateway/latest/) is an open source and flexible Kubernetes-native ingress controller and next-generation API gateway that is built on top of Envoy proxy.

1. Install Gloo Gateway via `helm`

Add the helm repo:
```bash,run
helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update
```

Install:
```bash,run
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

The installation is using these values to configure a simple installation:

- `discovery.enabled`: Gloo Gateway can perform service discovery for various upstreams (such as Kubernetes services and OpenAPI/Swagger services) and generates intermediary representations. For this tutorial, we’ll use only Kubernetes services, so the separate Gloo discovery service is unnecessary.
- `gatewayProxies.gatewayProxy.disabled`: Disables the default API Gateway from being created by Gloo. Instead, we’ll use a Kubernetes Gateway resource to set up our Gateway.
- `gloo.disableLeaderElection`:  Turns off leader election for a simpler setup.
- `kubeGateway.enabled`: Enables the Kubernetes Gateway API.

> [!NOTE]
> Gloo Gateway's installation will create a default GatewayClass so we do not need to apply the GatewayClass resource.

2. View the Gloo Gateway GatewayClass resources installed

```bash,run
kubectl get gatewayclass
```

You should see one GatewayClass controller:
```,nocopy
NAME             CONTROLLER                    ACCEPTED   AGE
gloo-gateway     solo.io/gloo-gateway          True       40s
```

3. Create the Gateway resource to replace the Istio Gateway

```bash,run
kubectl replace -f labs/07/gloo-gateway.yaml
```

Notice the `gatewayClassName: gloo-gateway` matches the GatewayClass resource from the previous step.

4. Check the Gateway was successfully created:
```bash,run
kubectl get deployments -n default
```

You should see a Gateway deployment named `gloo-proxy-gw` was created in the `default` namespace:
```,nocopy
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
gloo-proxy-gw   1/1     1            1           5s
```

5. Re-setup the environment variables

For Gloo Gateway you can use these values:
```bash,run
export GW_NAMESPACE=default
export GW_ADDRESS=$(kubectl get svc -n $GW_NAMESPACE gloo-proxy-gw -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $GW_ADDRESS
```

- `kubectl get svc -n $GW_NAMESPACE gloo-proxy-gw` retrieves the kubernetes service details for the Gloo Gateway we created via the Kubernetes Gateway API.
- `-o jsonpath='{.status.loadBalancer.ingress[0].ip}'` extracts just the external IP address from the service's status.

Let's switch to [Terminal 2](tab-1) and begin the port forward to view the Argo Demo App UI:
```bash,run
kubectl port-forward service/gloo-proxy-gw 8080:80 --address 0.0.0.0
```

### Envoy Gateway
===============

[Envoy Gateway](https://gateway.envoyproxy.io/docs/) is an open source Envoy subproject for managing Envoy-based application gateways.

1. Install the Envoy Gateway via `helm`.

```bash,run
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version v1.1.2 -n envoy-gateway-system --create-namespace
```

2. Create the Gateway Class resource

```bash,run
cat labs/07/envoy-gateway-class.yaml | yq
```

Apply the config:
```bash,run
kubectl apply -f labs/07/envoy-gateway-class.yaml
```

> [!NOTE]
> Envoy Gateway's installation does _not_ create a default GatewayClass so we need to apply the GatewayClass resource manually.

Check that the GatewayClass was created:
```bash,run
kubectl get gatewayclass
```

You should see the envoy controller `gateway.envoyproxy.io/gatewayclass-controller`:
```,nocopy
NAME             CONTROLLER                                      ACCEPTED   AGE
gw               gateway.envoyproxy.io/gatewayclass-controller   True       58s
```

3. Create the Gateway resources

```bash,run
cat labs/07/envoy-gateway.yaml | yq
```

Replace the Istio Gateway we created earlier:
```bash,run
kubectl replace -f labs/07/envoy-gateway.yaml
```

You will notice that the Gateway resource you applied configures the controller to match the GatewayClass with `controllerName: gateway.envoyproxy.io/gatewayclass-controller`.

4. To verify that the Gateway deployment was successfully created in the `envoy-gateway-system` namespace, run:
```bash,run
kubectl get deployment -n envoy-gateway-system
```

You should see a deployment with a name similar to `envoy-default-gw-<hash>` in addition to the default `envoy-gateway` gateway that was created during the helm install step:
```,nocopy
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
envoy-default-gw-3d45476e   1/1     1            1           2m15s
envoy-gateway               1/1     1            1           3m24s
```

5. Re-setup the environment variables

For Envoy Gateway you can use these values:
```bash,run
export GW_NAMESPACE=envoy-gateway-system
export GW_ADDRESS=$(kubectl get svc -n $GW_NAMESPACE -l gateway.envoyproxy.io/owning-gateway-name=gw -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
echo $GW_ADDRESS
```

- `kubectl get svc -n $GW_NAMESPACE  -l gateway.envoyproxy.io/owning-gateway-name=gw` retrieves the kubernetes service details for the Envoy Gateway we created via the Kubernetes Gateway API.
- `-o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'` extracts just the external IP address from the service's status for the first service.

Let's switch to [Terminal 2](tab-1) and begin the port forward to view the Argo Demo App UI:
```bash,run
kubectl port-forward service/$(kubectl get service -l gateway.envoyproxy.io/owning-gateway-name=gw  -n envoy-gateway-system -o jsonpath='{.items[0].metadata.name}')  -n envoy-gateway-system 8080:80 --address 0.0.0.0
```

### NGNIX Gateway Fabric
===============

[NGINX Gateway Fabric](https://github.com/nginxinc/nginx-gateway-fabric) is an open-source project that provides an implementation of the Gateway API using NGINX as the data plane. The goal of this project is to implement the core Gateway API to configure an HTTP or TCP/UDP load balancer, reverse-proxy, or API gateway for applications running on Kubernetes.

1. Install the NGNIX Gateway Fabric via `helm`.

```bash,run
helm upgrade --install ngf oci://ghcr.io/nginxinc/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway --version=1.2.0
```

2. Check that the GatewayClass was created:
```bash,run
kubectl get gatewayclass
```

You should see one GatewayClass controller:
```,nocopy
NAME             CONTROLLER                                      ACCEPTED   AGE
nginx            gateway.nginx.org/nginx-gateway-controller      True       103s
```

> [!NOTE]
> NGNIX Gateway Fabric's installation will create a default GatewayClass so we do not need to apply the GatewayClass resource.

3. Apply a Gateway

```bash,run
cat labs/07/ngnix-gateway.yaml | yq
```

```bash,run
kubectl replace -f labs/07/ngnix-gateway.yaml
```

4. Check the Gateway was successfully created:
```bash,run
kubectl get deployments -n nginx-gateway
```

You should see a Gateway deployment named `ngf-nginx-gateway-fabric` was created in the `nginx-gateway` namespace:

```,nocopy
NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
ngf-nginx-gateway-fabric   1/1     1            1           3m33s
```

5. Re-setup the environment variables

For NGNIX Gateway Fabric you can use these values:
```bash,run
export GW_NAMESPACE=nginx-gateway
export GW_ADDRESS=$(kubectl get svc -n $GW_NAMESPACE ngf-nginx-gateway-fabric -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $GW_ADDRESS
```

- `kubectl get svc -n $GW_NAMESPACE ngf-nginx-gateway-fabric` retrieves the kubernetes service details for the NGNIX Gateway Fabric  we created via the Kubernetes Gateway API.
- `-o jsonpath='{.status.loadBalancer.ingress[0].ip}'` extracts just the external IP address from the service's status.

Let's switch to [Terminal 2](tab-1) and begin the port forward to view the Argo Demo App UI:
```bash,run
kubectl port-forward service/ngf-nginx-gateway-fabric -n nginx-gateway 8080:80 --address 0.0.0.0
```

## Apply HTTPRoute to the Gateway namespace
===============

Create an HTTPRoute that selects the Gateway:
```bash,run
cat labs/07/argo-httproute.yaml | yq
```

Notice the HTTPRoute select the Gateway we created earlier via the `parentRefs`:
```,nocopy
  parentRefs:
    - name: gw
```

Apply the config:
```bash,run
kubectl apply -f labs/07/argo-httproute.yaml
```

## Send Traffic Through the Gateway
===============

We can now send traffic through the Gateway to the argo demo service:
```bash,run
curl http://$GW_ADDRESS:80/color
```

You should get a `200 OK` response back that looks like this:
```,nocopy
"purple"
```

🏁 Finish
=========

Great! Now that we can send traffic through our Gateway, let's look at how we can use Argo Rollouts to gradually deliver an upgraded version. Leave the config we applied, we will reuse it in the next step!