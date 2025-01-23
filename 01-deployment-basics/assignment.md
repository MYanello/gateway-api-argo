# Kubernetes Deployments

The most common way to manage workloads in Kubernetes today is with the `Deployment` resource.
A `Deployment` allows users to describe a workload as a set of `Pods`.
Behind the scenes, the `Deployment` controller manages `ReplicaSets` resources, which then drive the creation of the correct `Pods`.

## Creating a Deployment

Let's start by creating a `Deployment` and exploring how they work.

A Kubernetes cluster has been provisioned on this VM using kind and `kubectl` is available for interacting with it. We can confirm that we have an empty cluster ready to go:

```bash,run
kubectl get all
```

We should see something like:
```,nocopy
# kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   35s
```

The majority of the exploration we do in this workshop will use the [Argo Rollouts demo app](https://github.com/argoproj/rollouts-demo).

This demo application visualizes the various deployment strategies and progressive delivery features of Argo Rollouts. It allows you to control the error and latency rate and will control the [status code](https://github.com/argoproj/rollouts-demo/blob/f528fdd2189e877dfb8a2de21b6989853e8e8d26/main.go#L188) based on the configured error rate and the [delay length](https://github.com/argoproj/rollouts-demo/blob/f528fdd2189e877dfb8a2de21b6989853e8e8d26/main.go#L177) based on the configured latency.

Let's take a look at the manifest:

```bash,run
bat labs/01/basic-demo-app.yaml | yq
```

Of note, we specify a certain number of replicas, a Pod template, and a `strategy` which dictates how updates are performed. We are using the `RollingUpdate` strategy, which will progressively spins up new versions of the application before scaling down old versions. There are a few knobs available to tune how the rolling update occurs, such as `maxSurge` and `maxUnavailable`.

Let's apply it:
```bash,run
kubectl apply -f labs/01/basic-demo-app.yaml
```

And now let's confirm it was created:
```bash,run
kubectl get all --show-labels
```

We should the `Deployment` and the resulting `ReplicaSet` and `Pods` as well.
Something like:
```,nocopy
NAME                                 READY   STATUS    RESTARTS   AGE     LABELS
pod/rollouts-demo-745497c98b-6qjzv   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b
pod/rollouts-demo-745497c98b-86hcn   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b
pod/rollouts-demo-745497c98b-bc6r5   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b
pod/rollouts-demo-745497c98b-bs5xb   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b
pod/rollouts-demo-745497c98b-dwklg   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b
pod/rollouts-demo-745497c98b-hhvjb   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b
pod/rollouts-demo-745497c98b-llsv7   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b
pod/rollouts-demo-745497c98b-lp29r   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b
pod/rollouts-demo-745497c98b-qd27c   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b
pod/rollouts-demo-745497c98b-sz2hg   1/1     Running   0          2m50s   app=rollouts-demo,pod-template-hash=745497c98b

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   LABELS
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   11m   component=apiserver,provider=kubernetes

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE     LABELS
deployment.apps/rollouts-demo   10/10   10           10          2m50s   app=rollouts-demo

NAME                                       DESIRED   CURRENT   READY   AGE     LABELS
replicaset.apps/rollouts-demo-745497c98b   10        10        10      2m50s   app=rollouts-demo,pod-template-hash=745497c98b
```

Notice that the full count of replicas are immediately created as this is the initial creation of the `Deployment`.

The `Deployment` controller created a `ReplicaSet` with the format of `[DEPLOYMENT-NAME]-[HASH]`.

That `ReplicaSet` then created a number of pods with a similar naming prefix.

You can also see the label `pod-template-hash` on the `ReplicaSet` and the `Pods` created. This is how each `Pod` is associated to the `ReplicaSet` and how the `ReplicaSet` is ultimately tied back to the `Deployment`.

This value of this label is a hash of the pod template used in the generated `ReplicaSet` and thus is different for every tangible change to the pod spec.

## Updating a Deployment

Now let's make a change to this `Deployment`.
A rollout is kicked off whenever a change to the pod template on the `Deployment` is found by the deployment controller.

We will update the `Deployment` by setting its image to a different version.
Then we will also watch the status of the deployment as it progresses:
```bash,run
kubectl set image deployment/rollouts-demo rollouts-demo=argoproj/rollouts-demo:orange
kubectl rollout status deploy/rollouts-demo --watch
```

Once the rollout is triggered it will automatically update according to its strategy without intervention.

We can see the new replicas spin up until the new version has the expected number of replicas.

After the rollout is successful, let's check the generated resources:
```bash,run
kubectl get all --show-labels
```

We should see the new pods with the new template hash, along with two `ReplicaSets`, the old and new, with the old and new template hash label as well.

Let's do one more rollout but watch the `ReplicaSets` to see the machinery in action:
```bash,run
kubectl set image deployment/rollouts-demo rollouts-demo=argoproj/rollouts-demo:red
kubectl get replicaset --show-labels --watch
```

We will see a replicaset created (with a new hash) and the desired replica count progress until the new version has successfully been propagated. We can check the pods are created as well:
```bash,run
kubectl get pods --show-labels
```

## Rolling Back

We can also do things like rolling back to a previous revision. We can see the history of this `Deployment`:
```bash,run
kubectl rollout history deploy/rollouts-demo
```

The `CHANGE-CAUSE` is empty because it relies on an annotation on the Deployment (which we have not done).

Let's check the details of the first revision and make sure the ReplicaSet is still around:
```bash,run
kubectl rollout history deploy/rollouts-demo --revision=1
kubectl get rs
```

Now let's rollback to revision 1 and watch it progress:
```bash,run
kubectl rollout undo deployment/rollouts-demo --to-revision=1
kubectl rollout status deploy/rollouts-demo --watch
```

Everything should be good, but let's do another sanity check by checking the events on the Deployment and the Pods we expect are running:
```bash,run
kubectl describe deploy/rollouts-demo
kubectl get po --show-labels
```

## Finish

Let's clean up the Deployment:
```bash,run
kubectl delete -f labs/01/basic-demo-app.yaml
```

So while `Deployments` are capable of providing a level of declarative control over your workloads, they are basic in nature and will likely require additional tooling/effort to get you to any type of sophisticated progressive delivery.

In the next challenge, we will explore how Argo Rollouts fills in the gaps of the basic Deployment resource to give us a sophisticated progressive delivery tool.

Click **Check** to move on to the next lab!
