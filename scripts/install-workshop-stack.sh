#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECONTEXT="${KUBECONTEXT:-k3d-k3s-default}"
ARGOCD_NS="${ARGOCD_NS:-argocd}"
KYVERNO_NS="${KYVERNO_NS:-kyverno}"
MONITORING_NS="${MONITORING_NS:-monitoring}"
TIMEOUT="${TIMEOUT:-10m}"

info() {
  echo "[INFO] $*"
}

wait_rollout() {
  local ns="$1"
  local selector="$2"
  info "Waiting for rollout in namespace ${ns} with selector ${selector}"
  kubectl --context "${KUBECONTEXT}" -n "${ns}" rollout status deploy -l "${selector}" --timeout="${TIMEOUT}"
}

info "Checking cluster connectivity"
kubectl --context "${KUBECONTEXT}" get nodes -o name >/dev/null

info "Creating namespaces"
kubectl --context "${KUBECONTEXT}" create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl --context "${KUBECONTEXT}" apply -f -
kubectl --context "${KUBECONTEXT}" create namespace "${KYVERNO_NS}" --dry-run=client -o yaml | kubectl --context "${KUBECONTEXT}" apply -f -
kubectl --context "${KUBECONTEXT}" create namespace "${MONITORING_NS}" --dry-run=client -o yaml | kubectl --context "${KUBECONTEXT}" apply -f -

info "Adding Helm repositories"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null 2>&1 || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

info "Installing kube-prometheus-stack"
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --kube-context "${KUBECONTEXT}" \
  --namespace "${MONITORING_NS}" \
  --values "${ROOT_DIR}/deploy/helm-values/kube-prometheus-stack-values.yaml" \
  --wait \
  --timeout "${TIMEOUT}"

info "Installing Kyverno"
helm upgrade --install kyverno kyverno/kyverno \
  --kube-context "${KUBECONTEXT}" \
  --namespace "${KYVERNO_NS}" \
  --values "${ROOT_DIR}/deploy/helm-values/kyverno-values.yaml" \
  --wait \
  --timeout "${TIMEOUT}"

info "Installing Argo CD"
helm upgrade --install argocd argo/argo-cd \
  --kube-context "${KUBECONTEXT}" \
  --namespace "${ARGOCD_NS}" \
  --values "${ROOT_DIR}/deploy/helm-values/argocd-values.yaml" \
  --wait \
  --timeout "${TIMEOUT}"

info "Waiting for core deployments"
wait_rollout "${ARGOCD_NS}" "app.kubernetes.io/part-of=argocd"
wait_rollout "${KYVERNO_NS}" "app.kubernetes.io/part-of=kyverno"

info "Applying workshop monitoring rule"
kubectl --context "${KUBECONTEXT}" apply -f "${ROOT_DIR}/observability/prometheus/rules.yaml"

info "Applying workshop policies"
kubectl --context "${KUBECONTEXT}" apply -f "${ROOT_DIR}/policies/kyverno/disallow-latest.yaml"
kubectl --context "${KUBECONTEXT}" apply -f "${ROOT_DIR}/policies/kyverno/require-requests.yaml"

info "Applying Argo CD Applications"
kubectl --context "${KUBECONTEXT}" apply -f "${ROOT_DIR}/gitops/argocd/demo-app.yaml"
kubectl --context "${KUBECONTEXT}" apply -f "${ROOT_DIR}/gitops/argocd/kyverno-policies.yaml"
kubectl --context "${KUBECONTEXT}" apply -f "${ROOT_DIR}/gitops/argocd/observability.yaml"

info "Installation completed"
info "Argo CD UI: kubectl --context ${KUBECONTEXT} -n ${ARGOCD_NS} port-forward svc/argocd-server 8081:80"
info "Grafana UI: kubectl --context ${KUBECONTEXT} -n ${MONITORING_NS} port-forward svc/monitoring-grafana 3000:80"
info "Grafana admin password: workshop"

