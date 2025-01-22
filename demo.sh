#!/bin/bash

. demo-magic.sh
TYPE_SPEED=30
clear

#pei "./setup-env.sh"
#pei "./setup-metallb.sh"

# Lab 1
function lab1() {
  pe "bat labs/01/basic-demo-app.yaml"

  pe "kubectl apply -f labs/01/basic-demo-app.yaml"
  pe "kubectl get all --show-labels"

  pe "kubectl set image deployment/rollouts-demo rollouts-demo=argoproj/rollouts-demo:orange"
  pei "kubectl rollout status deploy/rollouts-demo --watch"

  pe "kubectl set image deployment/rollouts-demo rollouts-demo=argoproj/rollouts-demo:red"
  pei "kubectl get replicaset --show-labels --watch"
  pe "kubectl get pods --show-labels"

  pe "kubectl rollout history deploy/rollouts-demo"
  pe "kubectl get rs"
  pe "kubectl rollout undo deployment/rollouts-demo --to-revision=1"
  pei "kubectl rollout status deploy/rollouts-demo --watch"

  pe "kubectl delete -f labs/01/basic-demo-app.yaml"
}
# Lab 2


