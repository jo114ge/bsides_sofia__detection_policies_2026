#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECONTEXT="${KUBECONTEXT:-k3d-k3s-default}"
REMOVE_NAMESPACES="${REMOVE_NAMESPACES:-true}"

info() {
  echo "[INFO] $*"
}

info "Removing demo application resources"
kubectl --context "${KUBECONTEXT}" delete -k "${ROOT_DIR}/apps/demo-app/overlays/workshop" --ignore-not-found

if [[ "${REMOVE_NAMESPACES}" == "true" ]]; then
  info "Removing workshop namespaces"
  kubectl --context "${KUBECONTEXT}" delete namespace demo argocd kyverno monitoring --ignore-not-found
fi

info "Cleanup completed"
