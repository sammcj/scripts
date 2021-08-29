#!/bin/bash

# Requires krew to be installed krew.sigs.k8s.io

kubectl krew install fields
kubectl krew install rakkess
kubectl krew install access-matrix
kubectl krew install pod-lens
kubectl krew install ctx
kubectl krew install ns
kubectl krew index add kvaps https://github.com/kvaps/krew-index
kubectl krew install kvaps/node-shell
kubectl krew install neat
kubectl krew install gadget
kubectl krew install deprecations
kubectl krew install allctx
kubectl krew install resource-capacity
kubectl krew install service-tree
kubectl krew install sick-pods