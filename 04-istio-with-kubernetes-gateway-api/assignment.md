
Install the Kubernetes Gateway API CRDs
===============

The Kubernetes Gateway API abstractions are expressed using Kubernetes custom resource definitions (CRDs). This is a great development because it helps to ensure that all implementations who support the standard will maintain compliance, and it also facilitates declarative configuration of the Gateway API. Note that these CRDs are not installed by default, ensuring that they are only available when users explicitly activate them.

Let’s install those CRDs on our cluster now.

```bash,run
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

Expect to see this response:

```text,nocopy
customresourcedefinition.apiextensions.k8s.io/gatewayclasses.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/gateways.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/httproutes.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/referencegrants.gateway.networking.k8s.io created
```

> [!NOTE]
> The Kubernetes Gateway API CRDs do not come installed by default on most Kubernetes clusters, so make sure they are installed before using the Gateway API.

Istio Again?
===============

We've already explored how Istio's ingress gateway can be used with Istio-native APIs. Istio also supports Kubernetes Gateway api resources to configure traffic.

1. Revisit existing istio installation

We can confirm everything is still installed:
```bash,run
istioctl version
echo
kubectl get pods -n istio-system
```

You should have output similar to:
```,nocopy
client version: 1.23.2
control plane version: 1.23.2
data plane version: 1.23.2 (1 proxies)

NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-64f9774bdc-b9xmn   1/1     Running   0          11m
istiod-868cc8b7d7-d7fd6                 1/1     Running   0          11m
```

2. View the Istio GatewayClass resources installed

Istio's installation will create a default GatewayClass:
```bash,run
kubectl get gatewayclass
```

You should see istio's GatewayClasses:
```,nocopy
NAME           CONTROLLER                    ACCEPTED   AGE
istio          istio.io/gateway-controller   True       11m
istio-remote   istio.io/unmanaged-gateway    True       11m
```

The `istio-remote` GatewayClass supports gateways that the Istio control plane cannot directly discover through the API server; it does not program the Gateway or generate Istio resources for it. This tutorial will _not_ use the `istio-remote` GatewayClass.

Instead, we’ll use the `istio` GatewayClass, which is managed by the `istio.io/gateway-controller` controller and is responsible for creating our Gateway.

It is worth pointing out that while we installed istio in the previous challenge and just installed the Gateway API CRDs, we see istio's GatewayClass resources created.
This is a pretty cool feature of Istio that allows the control plane to delay starting controllers for various API types until it detects the corresponding CRD exists in the cluster.
In this case, it detected the presence of the `GatewayClass` CRD and then created the default GatewayClasses.

3. Create a Gateway

Our first step is to use the Kubernetes Gateway API to create a Gateway:
```bash,run
bat labs/04/istio-gateway.yaml | yq
```

Notice the `gatewayClassName: istio` matches the GatewayClass resource from the previous step.

Apply the config with:
```bash,run
kubectl apply -f labs/04/istio-gateway.yaml
```

5. Check the Gateway was successfully created:
```bash,run
kubectl get deployments -n default
```

You should see a Gateway deployment named `gw-istio` was created in the `default` namespace:
```,nocopy
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
gw-istio   1/1     1            1           6s
```

We have a Gateway! 🚀

Now let's move on to the next section and route some traffic to our newly created Gateway.

Setup your Environment
===============

Like we did in the previous challenge, we need to set up some environment variables to simplify accessing the Gateway:

```bash,run
export GW_NAMESPACE=default
export GW_ADDRESS=$(kubectl get svc -n $GW_NAMESPACE gw-istio -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $GW_ADDRESS
```

> [!NOTE]
> The GW_ADDRESS here is the IP address of the `gw-istio` that was created by the Gateway resource we applied earlier.

- `kubectl get svc -n $GW_NAMESPACE gw-istio` retrieves the kubernetes service details for the Istio gateway we created via the Kubernetes Gateway API.
- `-o jsonpath='{.status.loadBalancer.ingress[0].ip}'` extracts just the external IP address from the service's status.

Also, we need to create our app we want to route to.
We'll use the same demo app and services we've used in the previous steps:
```bash,run
kubectl apply -f labs/04/services.yaml
kubectl apply -f labs/04/rollout.yaml
```

> [!NOTE]
> In this challenege we are not actually using any rollouts features, we are just using a `Rollout` to spin up the pods needed to act as a backend for our routing.

Apply HTTPRoute to the Gateway namespace
===============

Next, we will use a new Gateway API resource, [HTTPRoute](https://gateway-api.sigs.k8s.io/guides/http-routing/) to direct traffic to our Kubernetes backends.

```bash,run
bat labs/04/argo-httproute.yaml | yq
```

Notice the HTTPRoute select the Gateway we created earlier via the `parentRefs`:
```yaml,nocopy
  parentRefs:
    - name: gw
```

Create an HTTPRoute that selects the Gateway:
```bash,run
kubectl apply -f labs/04/argo-httproute.yaml
```

Send Traffic Through the Gateway
===============

We can now send traffic through the Gateway to the argo demo service:
```bash,run
curl $GW_ADDRESS:80/color
```

You should get a `200 OK` response back that looks like this:
```,nocopy
"blue"
```

Let's confirm the UI works as well, so run the port-forward command:
```bash,run
kubectl port-forward svc/gw-istio 8080:80 --address 0.0.0.0
```

And open the [Demo App tab](tab-1) to view the Argo Demo visualization.

URL Rewrite with Gateway API
===============

Let's take a look at the config:
```bash,run
bat labs/04/url-rewrite.yaml | yq
```

In order to get the URL Rewrite to work with Kubernetes Gateway API we need to add a filter to the rule:
```,nocopy
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplaceFullPath
              replaceFullPath: /color
```

Apply the config to overwrite our existing HTTPRoute:
```bash,run
kubectl apply -f labs/04/url-rewrite.yaml
```

Send some traffic to the new `favorite-color` route in verbose mode:
```bash,run
curl $GW_ADDRESS:80/favorite-color -v
```

You should see a response that looks like this:
```,nocopy
*   Trying 172.18.255.1:80...
* Connected to 172.18.255.1 (172.18.255.1) port 80 (#0)
> GET /favorite-color HTTP/1.1
> Host: 172.18.255.1
> User-Agent: curl/7.81.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< content-type: text/plain; charset=utf-8
< x-content-type-options: nosniff
< date: Tue, 12 Nov 2024 19:58:27 GMT
< content-length: 6
< x-envoy-upstream-service-time: 0
< server: istio-envoy
<
* Connection #0 to host 172.18.255.1 left intact
```

Notice the request is going through the Istio gateway and using the `/favorite-color` path.

> [!NOTE]
> The Gateway API redirect and rewrite filters are mutually incompatible. Rules cannot use both filter types at once. You can learn more in the [Gateway API docs](https://gateway-api.sigs.k8s.io/guides/http-redirect-rewrite/).


Advanced Task: Add a HTTP Header with Gateway API 💪
===============

The HTTPRoute can also modify the headers of HTTP requests and the HTTP responses from clients. There are two types of filters available to meet these requirements: `RequestHeaderModifier` and `ResponseHeaderModifier`.

Let's add a new header `x-location: salt-lake-city` on the response to our HTTPRoute that already had our URLRewrite filter. Use the Gateway API filters to add this header to the route.

You can test if this is working with:
```bash,run
curl $GW_ADDRESS:80/favorite-color -v
```

You should see a response with the header added:
```,nocopy
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< content-type: text/plain; charset=utf-8
< x-content-type-options: nosniff
< date: Wed, 13 Nov 2024 18:22:14 GMT
< content-length: 6
< x-envoy-upstream-service-time: 0
< x-location: salt-lake-city
< server: istio-envoy
```

**Hint**: Check out the [Gateway API docs](https://gateway-api.sigs.k8s.io/guides/http-header-modifier/) for some examples.

🏁 Finish
=========

Let's cleanup our Route and Rollout:
```bash,run
kubectl delete -f labs/04/argo-httproute.yaml
kubectl delete -f labs/04/rollout.yaml
kubectl delete -f labs/04/services.yaml
```

Great! Now that we can send traffic through our Gateway, let's look at how we can use Argo Rollouts to gradually deliver an upgraded version.

To complete this challenge, press **Check**
