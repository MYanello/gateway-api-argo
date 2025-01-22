#!/bin/bash

. demo-magic.sh
TYPE_SPEED=40
clear

# pe "./setup-env.sh"
# pe "./setup-metallb.sh"

# p "Lab 1"
# pe "bat labs/01/basic-demo-app.yaml"

# pe "kubectl apply -f labs/01/basic-demo-app.yaml"
# pe "kubectl get all --show-labels"

# pe "kubectl set image deployment/rollouts-demo rollouts-demo=argoproj/rollouts-demo:orange"
# pei "kubectl rollout status deploy/rollouts-demo --watch"

# pe "kubectl set image deployment/rollouts-demo rollouts-demo=argoproj/rollouts-demo:red"
# pei "kubectl get replicaset --show-labels --watch"
# pe "kubectl get pods --show-labels"

# pe "kubectl rollout history deploy/rollouts-demo"
# pe "kubectl get rs"
# pe "kubectl rollout undo deployment/rollouts-demo --to-revision=1"
# pei "kubectl rollout status deploy/rollouts-demo --watch"

# pe "kubectl delete -f labs/01/basic-demo-app.yaml"


# p "Lab 2"
# pe "helm upgrade --install argo-rollouts argo-rollouts --repo https://argoproj.github.io/argo-helm --version 2.37.6 --namespace argo-rollouts --create-namespace --wait"
# pe "kubectl get pods -n argo-rollouts"

# p "Create the initial rollout"
# pe "bat labs/02/rollout.yaml"
# pe "kubectl apply -f labs/02/rollout.yaml"
# pe "kubectl get rollouts.argoproj.io,all"
# pe "kubectl argo rollouts get rollout rollouts-demo"

# p "Create the update"
# pe "kubectl argo rollouts set image rollouts-demo rollouts-demo=argoproj/rollouts-demo:yellow"
# pei "kubectl argo rollouts get rollout rollouts-demo --watch"

# p "Promote the canary"
# pe "kubectl argo rollouts promote rollouts-demo"
# pei "kubectl argo rollouts get rollout rollouts-demo --watch"

# p "Promote via the dashboard"
# pe "kubectl argo rollouts dashboard"

# p "Make a bad update"
# pe "kubectl argo rollouts set image rollouts-demo rollouts-demo=argoproj/rollouts-demo:bad-purple"
# pei "kubectl argo rollouts get rollout rollouts-demo --watch"

# # Abort the bad update
# pe "kubectl argo rollouts abort rollouts-demo"
# pei "kubectl argo rollouts get rollout rollouts-demo --watch"

# Can also do a full promotion all at once with --full
#
# p "Lab 3"
# pe "istioctl install -y"
# pe "kubectl get deploy -n istio-system"
# pe "kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
pe "export GW_ADDRESS=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

# pe "bat labs/03/services.yaml"
# p "Create the canary and stable services"
# pe "kubectl apply -f labs/03/services.yaml"

p "Create the istio routing config"
pe "bat labs/03/istio-basic.yaml"
pe "kubectl apply -f labs/03/istio-basic.yaml"
