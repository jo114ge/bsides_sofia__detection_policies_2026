#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECONTEXT="${KUBECONTEXT:-k3d-k3s-default}"
ARGOCD_NS="${ARGOCD_NS:-argocd}"
KYVERNO_NS="${KYVERNO_NS:-kyverno}"
MONITORING_NS="${MONITORING_NS:-monitoring}"
DEMO_NS="${DEMO_NS:-demo}"
REMOVE_NAMESPACES="${REMOVE_NAMESPACES:-false}"
REMOVE_CRDS="${REMOVE_CRDS:-true}"
FORCE_FINALIZE_NAMESPACES="${FORCE_FINALIZE_NAMESPACES:-true}"

info() {
  echo "[INFO] $*"
}

finalize_namespace() {
  local ns="$1"
  local tmpfile

  if ! kubectl --context "${KUBECONTEXT}" get namespace "${ns}" >/dev/null 2>&1; then
    return 0
  fi

  tmpfile="$(mktemp)"
  kubectl --context "${KUBECONTEXT}" get namespace "${ns}" -o json > "${tmpfile}"
  jq '.spec.finalizers=[]' "${tmpfile}" | kubectl --context "${KUBECONTEXT}" replace --raw "/api/v1/namespaces/${ns}/finalize" -f - >/dev/null
  rm -f "${tmpfile}"
}

delete_crd_if_present() {
  local crd="$1"
  if kubectl --context "${KUBECONTEXT}" get crd "${crd}" >/dev/null 2>&1; then
    kubectl --context "${KUBECONTEXT}" delete crd "${crd}"
  fi
}

remove_release() {
  local release="$1"
  local ns="$2"

  if helm --kube-context "${KUBECONTEXT}" -n "${ns}" status "${release}" >/dev/null 2>&1; then
    info "Uninstalling Helm release ${release} from namespace ${ns}"
    helm uninstall "${release}" --kube-context "${KUBECONTEXT}" -n "${ns}"
  else
    info "Release ${release} not present in namespace ${ns}"
  fi
}

info "Removing workshop Argo CD Applications and policies if present"
kubectl --context "${KUBECONTEXT}" delete -f "${ROOT_DIR}/gitops/argocd/demo-app.yaml" --ignore-not-found
kubectl --context "${KUBECONTEXT}" delete -f "${ROOT_DIR}/gitops/argocd/kyverno-policies.yaml" --ignore-not-found
kubectl --context "${KUBECONTEXT}" delete -f "${ROOT_DIR}/gitops/argocd/observability.yaml" --ignore-not-found
kubectl --context "${KUBECONTEXT}" delete -f "${ROOT_DIR}/policies/kyverno/disallow-latest.yaml" --ignore-not-found
kubectl --context "${KUBECONTEXT}" delete -f "${ROOT_DIR}/policies/kyverno/require-requests.yaml" --ignore-not-found
kubectl --context "${KUBECONTEXT}" delete -f "${ROOT_DIR}/observability/prometheus/rules.yaml" --ignore-not-found
kubectl --context "${KUBECONTEXT}" delete -k "${ROOT_DIR}/apps/demo-app/overlays/workshop" --ignore-not-found

remove_release argocd "${ARGOCD_NS}"
remove_release kyverno "${KYVERNO_NS}"
remove_release monitoring "${MONITORING_NS}"

if [[ "${REMOVE_NAMESPACES}" == "true" ]]; then
  info "Removing namespaces"
  kubectl --context "${KUBECONTEXT}" delete namespace "${DEMO_NS}" "${ARGOCD_NS}" "${KYVERNO_NS}" "${MONITORING_NS}" --ignore-not-found
fi

if [[ "${REMOVE_CRDS}" == "true" ]]; then
  info "Removing residual workshop CRDs"
  delete_crd_if_present applications.argoproj.io
  delete_crd_if_present applicationsets.argoproj.io
  delete_crd_if_present appprojects.argoproj.io
  delete_crd_if_present alertmanagerconfigs.monitoring.coreos.com
  delete_crd_if_present alertmanagers.monitoring.coreos.com
  delete_crd_if_present podmonitors.monitoring.coreos.com
  delete_crd_if_present probes.monitoring.coreos.com
  delete_crd_if_present prometheusagents.monitoring.coreos.com
  delete_crd_if_present prometheuses.monitoring.coreos.com
  delete_crd_if_present prometheusrules.monitoring.coreos.com
  delete_crd_if_present scrapeconfigs.monitoring.coreos.com
  delete_crd_if_present servicemonitors.monitoring.coreos.com
  delete_crd_if_present thanosrulers.monitoring.coreos.com
fi

if [[ "${FORCE_FINALIZE_NAMESPACES}" == "true" ]]; then
  info "Force-finalizing any stuck workshop namespaces"
  finalize_namespace "${DEMO_NS}"
  finalize_namespace "${ARGOCD_NS}"
  finalize_namespace "${KYVERNO_NS}"
  finalize_namespace "${MONITORING_NS}"
fi

info "Uninstall completed"
