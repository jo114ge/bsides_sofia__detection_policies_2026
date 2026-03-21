#!/usr/bin/env bash

set -euo pipefail

KUBECONTEXT="${KUBECONTEXT:-k3d-k3s-default}"

info() {
  echo "[INFO] $*"
}

info "Creating workshop namespaces if missing"
kubectl --context "${KUBECONTEXT}" create namespace demo --dry-run=client -o yaml | kubectl --context "${KUBECONTEXT}" apply -f -
kubectl --context "${KUBECONTEXT}" create namespace argocd --dry-run=client -o yaml | kubectl --context "${KUBECONTEXT}" apply -f -
kubectl --context "${KUBECONTEXT}" create namespace kyverno --dry-run=client -o yaml | kubectl --context "${KUBECONTEXT}" apply -f -
kubectl --context "${KUBECONTEXT}" create namespace monitoring --dry-run=client -o yaml | kubectl --context "${KUBECONTEXT}" apply -f -

info "Namespaces ready"

