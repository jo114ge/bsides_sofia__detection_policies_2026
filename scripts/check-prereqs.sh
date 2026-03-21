#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-k3s-default}"
KUBECONTEXT="${KUBECONTEXT:-k3d-${CLUSTER_NAME}}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "[INFO] $*"
}

check_bin() {
  local bin="$1"
  command -v "$bin" >/dev/null 2>&1 || fail "Missing required binary: ${bin}"
  info "Found ${bin}: $(command -v "$bin")"
}

check_bin k3d
check_bin kubectl
check_bin docker

info "Checking Docker daemon connectivity"
docker info >/dev/null

info "Checking k3d clusters"
k3d cluster list

info "Checking kubectl context ${KUBECONTEXT}"
kubectl config get-contexts "${KUBECONTEXT}" >/dev/null 2>&1 || fail "kubectl context ${KUBECONTEXT} not found"

info "Checking API server connectivity"
kubectl --context "${KUBECONTEXT}" get nodes -o name

info "Detecting optional workshop CRDs"
if kubectl --context "${KUBECONTEXT}" api-resources | grep -qi kyverno; then
  info "Kyverno CRDs detected"
else
  info "Kyverno CRDs not detected"
fi

if kubectl --context "${KUBECONTEXT}" api-resources | grep -qi applications.argoproj.io; then
  info "Argo CD CRDs detected"
else
  info "Argo CD CRDs not detected"
fi

if kubectl --context "${KUBECONTEXT}" api-resources | grep -qi prometheusrules.monitoring.coreos.com; then
  info "Prometheus Operator CRDs detected"
else
  info "Prometheus Operator CRDs not detected"
fi

info "Prerequisite check completed"
info "Repository root: ${ROOT_DIR}"

