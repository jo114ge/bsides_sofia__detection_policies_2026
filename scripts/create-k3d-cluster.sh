#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-workshop}"
API_PORT="${API_PORT:-6550}"
HTTP_PORT="${HTTP_PORT:-8080}"
HTTPS_PORT="${HTTPS_PORT:-8443}"
AGENTS="${AGENTS:-1}"

info() {
  echo "[INFO] $*"
}

if k3d cluster list | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  info "Cluster ${CLUSTER_NAME} already exists"
  exit 0
fi

info "Creating k3d cluster ${CLUSTER_NAME}"
k3d cluster create "${CLUSTER_NAME}" \
  --api-port "${API_PORT}" \
  --agents "${AGENTS}" \
  --port "${HTTP_PORT}:80@loadbalancer" \
  --port "${HTTPS_PORT}:443@loadbalancer" \
  --wait

info "Cluster ${CLUSTER_NAME} created"
info "kubectl context: k3d-${CLUSTER_NAME}"

