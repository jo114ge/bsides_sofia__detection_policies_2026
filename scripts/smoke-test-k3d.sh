#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECONTEXT="${KUBECONTEXT:-k3d-k3s-default}"

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*"
}

info "Bootstrapping namespaces"
"${ROOT_DIR}/scripts/bootstrap-demo-namespaces.sh"

info "Applying base application resources"
kubectl --context "${KUBECONTEXT}" apply -k "${ROOT_DIR}/apps/demo-app/overlays/workshop"

info "Waiting for demo deployment rollout"
kubectl --context "${KUBECONTEXT}" -n demo rollout status deployment/demo-app --timeout=120s

info "Checking service endpoints"
kubectl --context "${KUBECONTEXT}" -n demo get deploy,svc,pods -o wide

if kubectl --context "${KUBECONTEXT}" api-resources | grep -qi kyverno; then
  info "Kyverno detected, validating policy manifests"
  kubectl --context "${KUBECONTEXT}" apply --dry-run=server -f "${ROOT_DIR}/policies/kyverno/disallow-latest.yaml"
  kubectl --context "${KUBECONTEXT}" apply --dry-run=server -f "${ROOT_DIR}/policies/kyverno/require-requests.yaml"
else
  warn "Kyverno CRDs not installed, skipping policy apply test"
fi

if kubectl --context "${KUBECONTEXT}" api-resources | grep -qi applications.argoproj.io; then
  info "Argo CD detected, validating Application manifests"
  kubectl --context "${KUBECONTEXT}" apply --dry-run=server -f "${ROOT_DIR}/gitops/argocd/demo-app.yaml"
  kubectl --context "${KUBECONTEXT}" apply --dry-run=server -f "${ROOT_DIR}/gitops/argocd/kyverno-policies.yaml"
  kubectl --context "${KUBECONTEXT}" apply --dry-run=server -f "${ROOT_DIR}/gitops/argocd/observability.yaml"
else
  warn "Argo CD CRDs not installed, skipping Application manifest test"
fi

if kubectl --context "${KUBECONTEXT}" api-resources | grep -qi prometheusrules.monitoring.coreos.com; then
  info "Prometheus Operator detected, validating alert rules"
  kubectl --context "${KUBECONTEXT}" apply --dry-run=server -f "${ROOT_DIR}/observability/prometheus/rules.yaml"
else
  warn "Prometheus Operator CRDs not installed, skipping PrometheusRule test"
fi

info "Smoke test completed"

