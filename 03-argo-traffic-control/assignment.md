Now that we have seen the workload management features of `Rollouts`, let's actually do something useful with those applications and send traffic to them.
There are several built-in providers that Argo Rollouts integrates with directly. We will choose Istio for now due to its ubiquity. While Istio is a service mesh, in this lab we will only be using its advanced ingress functionality.
 > [!NOTE]
 > The majority of the concepts we will explore in this lab are applicable to many of the other traffic management providers, however some of them do not support the full set of traffic control features.


Install Istio
=============
`istioctl`, the cli tool for Istio, is available on our VM, so let's use it to install Istio:
```bash,run
istioctl install -y
```

Now let's check that we have the control plane `istiod` running and the ingress gateway which will handle our ingress traffic:
```bash,run
kubectl get deploy -n istio-system
```

As mentioned above, for our lab we are only going to use the ingress features. The `istio-ingressgateway` deployment is an Istio-extended Envoy proxy that will handle our ingress traffic.

Let's grab the `LoadBalancer` IP for the `istio-ingressgateway` service. In this workshop, the IPs are assigned and exposed via `MetalLB`, but this typically will come from your cloud provider or something like Cilium.
```bash,run
export GW_ADDRESS=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $GW_ADDRESS
```

> [!NOTE]
> The GW_ADDRESS here is the IP address of the `istio-ingressgateway` that was created when we installed Istio in the earlier step.

Traffic Routing with Istio
==========================

## Create our application Rollout

View and create our K8s `Services`:
```bash,run
cat labs/03/services.yaml | yq
kubectl apply -f labs/03/services.yaml
```

We have created two `Services` corresponding to the stable and canary versions of our demo app.
As the comments indicate, the selectors of these services will be modified by the rollout controller to select pods by correct ReplicaSet as canary deployments are deployed and progress.

View and create Istio-specific routing config:
```bash,run
cat labs/03/istio-basic.yaml | yq
kubectl apply -f labs/03/istio-basic.yaml
```

This is a very basic set of istio configuration that will expose a routing config on the ingress gateway that will route 100% of incoming traffic to the `rollouts-demo-stable` service.

Now we need to create a `Rollout` to actually deploy our application.
First, let's compare this Rollout to the basic Rollout in the previous challenge:
```bash,run
git -P diff --no-index labs/02/rollout.yaml labs/03/rollout.yaml
```

There are three main changes worth discussing:
 1. We have reduced our rollout to only use a single replica. Since we are integrating with Istio, we no longer need to use replica count to provide weighted routing.
 2. The definition of the stable and canary `Services`. This is how the rollouts controller knows which Services to modify.
 3. The addition of an `istio` specific configuration for `trafficRouting`. Here we define the Istio `VirtualService` name and the route configuration in that `VirtualService` we want the rollouts controller to modify as the rollout progresses.

Let's quickly take another look at the http routing config for Istio `VirtualService` we just created:
```bash,run
kubectl get virtualservices.networking.istio.io rollouts-demo -o yaml | yq '.spec.http'
```

So we can see how the rollout controller is linked to the route named `primary` in our VirtualService named `rollouts-demo`.

Now let's create this `Rollout`:
```bash,run
kubectl apply -f labs/03/rollout.yaml
```

Check created resources:
```bash,run
kubectl get all
kubectl get rollouts.argoproj.io
kubectl get gateways.networking.istio.io
kubectl get virtualservices.networking.istio.io
```

 > [!NOTE]
 > Remember, on initial creation of the `Rollout` there will be no canary and it will immediately progress to the full replica count.

We see our expected resources including the dynamically created single `Pod` for our demo app.
Let's dig a bit deeper and see how the `Services` were updated:

```bash,run
kubectl get svc rollouts-demo-stable -o yaml | yq
```

We see a new annotation:
```yaml,nocopy
metadata:
  annotations:
    argo-rollouts.argoproj.io/managed-by-rollouts: rollouts-demo
```

And we see the selector now contains the hash for the stable `ReplicaSet` and pods:
```yaml,nocopy
  selector:
    app: rollouts-demo
    rollouts-pod-template-hash: 687d76d795
```

Let's confirm with the rollouts details:
```bash,run
kubectl argo rollouts get rollout rollouts-demo
```

We should see the hash for revision 1 matches the selector on the service (and the pod).

We can also check the canary service selector (along with the stable service selector for good measure):
```bash,run
echo "canary"
kubectl get svc rollouts-demo-canary -o yaml | yq '.spec.selector'
echo "stable"
kubectl get svc rollouts-demo-stable -o yaml | yq '.spec.selector'
```

And we will see the exact same hash used in the selector. Since we are not currently performing a canary, the stable and canary services are equivalent.
However, as we are not routing any traffic to the canary service, in our case it isn't relevant!

## Access the Demo App

Now that we see the correct resources in place and understand how they are wired up, let's actually send traffic to our demo app.
Since this `Service` is of type `LoadBalancer`, it should be reachable at the external IP address.

```bash,run
curl -v -w "\n" $GW_ADDRESS/color
```

You should see something like:
```,nocopy
*   Trying 172.18.255.0:80...
* Connected to 172.18.255.0 (172.18.255.0) port 80 (#0)
> GET /color HTTP/1.1
> Host: 172.18.255.0
> User-Agent: curl/7.81.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< content-type: text/plain; charset=utf-8
< x-content-type-options: nosniff
< date: Sun, 10 Nov 2024 22:31:21 GMT
< content-length: 6
< x-envoy-upstream-service-time: 0
< server: istio-envoy
<
* Connection #0 to host 172.18.255.0 left intact
"blue"
```

So our demo app is actually serving traffic! But it's not just a simple endpoint, it is a full web-based UI that will help us visualize the progressive delivery features of Argo Rollouts.

The UI itself doesn't play nicely with the Instruqt UI, so we need to access it in a separate browser tab.
We also need to do some special networking to make it work, specifically we will use port forwarding to make it accessible to the outside world.

Let's switch to [Terminal 2](tab-1) and begin the port forward.

```bash,run
kubectl port-forward -n istio-system service/istio-ingressgateway 8080:80 --address 0.0.0.0
```

We will leave this port-forward running in "Terminal 2" for now.

Now we can switch to the tab [Demo App tab](tab-2) and we should see the demo application running. Be sure the link opens in a new tab or window outside of the Instruqt platform.

We should see only blue squares sucessfully showing up.

## Performing a Rollout

Let's switch back to [Terminal 1](tab-0).

Now let's make a change to the Rollout spec and trigger a new rollout which will trigger a new canary. Rather than explicitly setting the image via the CLI, this time we will apply a change with a new version of the Rollout manifest.

```bash,run
git -P diff --no-index labs/03/rollout.yaml labs/03/rollout-yellow.yaml
```

The only difference is the image version in our Pod spec. Let's apply it:
```bash,run
kubectl apply -f labs/03/rollout-yellow.yaml
```

Now the controller will detect an actionable change to the Rollout, create a canary `ReplicaSet`, and set the weight to 25% for the canary.

As we are now integrating with a traffic router, in this case Istio, we are able to intelligently and precisely control the traffic weight without having to rely on simple replica counts.
Remember, in this example, we only have a single replica, yet can do percentage-based traffic shaping.

First, let's see the changes made to the `VirtualService`:
```bash,run
kubectl get virtualservices.networking.istio.io rollouts-demo -o yaml | yq
```

Notice how the weights have changed to represent the percentages from whichever step of the canary the rollout is currently at. In our case, we're paused with 25% weighted towards the canary.
```yaml,nocopy
    http:
    - name: primary
      route:
        - destination:
            host: rollouts-demo-stable
          weight: 75
        - destination:
            host: rollouts-demo-canary
          weight: 25
```

Let's also check the `services`:
```bash,run
echo "stable service selector"
kubectl get svc rollouts-demo-stable -o yaml | yq '.spec.selector'
echo "canary service selector"
kubectl get svc rollouts-demo-canary -o yaml | yq '.spec.selector'
```

And compare them with the hashes of the rollout. This time we will inspect the status of the rollout for a concise view:
```bash,run
kubectl get rollout rollouts-demo -o yaml | yq '.status.canary'
```

The stable service has the same selector but now the canary service selector has been updated to the new hash.

So the argo rollouts controller took care of the following:
 1. Deploy new ReplicaSet for the canary version
 2. Modify `Service` selector for canary to point to new ReplicaSet
 3. Modify weights on the `VirtualService` to match which step we are at

Let's see it in action.
Switch back to the demo app and you should see roughly 25% of the requests result in a yellow square, something like:
insert screenshot here

The Rollout is paused waiting for feedback. In our case, we have validated that the new yellow version of our app works great, so let's go ahead and promote the rollout.

```bash,run
kubectl argo rollouts promote rollouts-demo
kubectl argo rollouts get rollout rollouts-demo --watch
```

Watching the demo app, we should see the app eventually receive 100% yellow responses and the rollout progresses this new image to be stable.

## Header-based traffic routing

Now let's take a look at a more advanced traffic routing feature.

Up until now, we have relied only on weight-based traffic control to send a subset of traffic to the canary deployment. This was achieved by manipulating the replica count in the basic use case and then via actually configuring the weight in the proxy/data-plane when using e.g. Istio to handle traffic routing.

But regardless of the implementation, weight-based control still means that all requests are effectively treated the same and the weighting is essentially random.
There are many reasons why you may want more control, such as to explicitly send some requests to the canary.
For example, you may be doing internal smoke testing and want to confirm with some manual steps that the canary is behaving as expected.

We can accomplish this with another Argo Rollouts feature built into the Canary strategy. A `SetHeaderRoute` step can be used to configure a route with a header match that will always be routed to the canary version. This allows a developer or tester to guarantee their request will access the canary version of the app.

Let's try it out now.
First, let's update the existing rollout. We can check what is changing by running:
```bash,run
git -P diff --no-index labs/03/rollout-yellow.yaml labs/03/rollout-with-header.yaml
```

The only change is the addition of a managed route section which dictates which route Argo Rollouts will add/modify and the `setHeaderRoute` step to configure this routing.
You can see that after we apply this, the 2nd step in the canary process will be configuring this header-based route and then pausing for a manual promotion. This will allow us to explicitly test the canary via the header route and once our testing is sufficient, promote the changes.

Let's apply it now:
```bash,run
kubectl apply -f labs/03/rollout-with-header.yaml
```

If we check the `Rollout` we will see there was no canary initiated:
```bash,run
kubectl argo rollouts get rollout rollouts-demo
```

This is because we did not modify the `spec.template` field of the `Rollout`.
Let's upgrade the app and kick off a new rollout:
```bash,run
kubectl argo rollouts set image rollouts-demo rollouts-demo=argoproj/rollouts-demo:orange
```

Now we have kicked off a canary, and if we check the Rollout status we will see we are paused on step 2/3:
```bash,run
kubectl argo rollouts get rollout rollouts-demo
```

If we check the demo app we should again see 25% of the requests being handled by the canary, in this case expressed as orange squares.
However, we can use the newly created header route to access the canary 100% of the time.

First, let's see the changes made to the `VirtualService`:
```bash,run
kubectl get virtualservices.networking.istio.io rollouts-demo -o yaml | yq
```

Note the new header route added:
```yaml,nocopy
    http:
    - match:
        - headers:
            x-rollout-canary:
              exact: "true"
      name: canary-header
      route:
        - destination:
            host: rollouts-demo-canary
          weight: 100
```

Now that this route is available, we can send a request with the correct header to route to the canary 100% of the time.

Let's try it out manually:
```bash,run
for i in {1..10}; do
  curl -H "x-rollout-canary: true" $GW_ADDRESS/color
  echo
done
```

You should see the following output:
```,nocopy
"orange"
"orange"
"orange"
"orange"
"orange"
"orange"
```

Try the same curl without the header again:
```bash,run
for i in {1..10}; do
  curl $GW_ADDRESS/color
  echo
done
```

You should see the loabalanced response between the stable and canary versions:
```,nocopy
"orange"
"orange"
"yellow"
"yellow"
"yellow"
"orange"
```

So even though "normal" traffic will be subject to weighted loadbalancing, with our special header we are able to route directly to the canary.

If we were able to detect issues with the canary, we would be able to e.g. abort the rollout before shifting more user traffic towards the canary.

In this case everything is working great, so let's finish off the rollout by promoting it.
```bash,run
kubectl argo rollouts promote rollouts-demo
```

We should see the demo app move to 100% orange.

🏁 Finish
=========

## Cleanup

Let's remove our resources to have a clean slate for the next challenge:
```bash,run
kubectl delete -f labs/03/services.yaml
kubectl delete -f labs/03/rollout.yaml
kubectl delete -f labs/03/istio-basic.yaml
```

## Check

To complete this challenge, press **Check**
