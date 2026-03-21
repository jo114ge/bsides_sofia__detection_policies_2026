# Workshop Demo Repo

This repository contains the material for a 3-hour workshop on Kubernetes Policy-as-Detection using Terraform, Argo CD, and Kyverno.

## Layout

- `terraform/`: bootstrap resources
- `apps/`: demo application manifests
- `policies/`: Kyverno policies in audit mode
- `gitops/`: Argo CD applications
- `observability/`: Prometheus, Grafana, and Alertmanager examples
- `tickets/`: example ticket payload
- `docs/`: delivery notes
- `scripts/`: local k3d bootstrap and smoke-test helpers
- `deploy/helm-values/`: reduced Helm values for local workshop installs
- `slides.md`: presentation deck in Markdown

## Demo Story

1. Start from a healthy baseline
2. Change replicas to prove GitOps works
3. Commit a risky change
4. Let Kyverno record the violation
5. Show the signal in observability
6. Fix through Git

## Important Constraint

This scaffold is intentionally minimal. It is designed for explanation and adaptation, not for production deployment as-is.

## Documentation

- [workshop-package.md](workshop-package.md): full workshop package — abstract, goals, agenda, and slide outline
- [slides.md](slides.md): presentation deck in Markdown

## Local k3d Test Flow

If you already have `k3d`, `kubectl`, and Docker installed:

```bash
./scripts/check-prereqs.sh
./scripts/bootstrap-demo-namespaces.sh
./scripts/smoke-test-k3d.sh
```

If you want a dedicated cluster for the workshop:

```bash
CLUSTER_NAME=workshop ./scripts/create-k3d-cluster.sh
KUBECONTEXT=k3d-workshop ./scripts/check-prereqs.sh
KUBECONTEXT=k3d-workshop ./scripts/smoke-test-k3d.sh
```

The smoke test always validates the base app. Kyverno, Argo CD, and Prometheus-specific validation only runs if their CRDs are already installed in the cluster.

## Install Full Workshop Stack On k3d

To install Kyverno, Argo CD, Prometheus, Alertmanager, and Grafana on the current cluster:

```bash
KUBECONTEXT=k3d-k3s-default ./scripts/install-workshop-stack.sh
```

To uninstall the stack:

```bash
KUBECONTEXT=k3d-k3s-default ./scripts/uninstall-workshop-stack.sh
```

To remove the namespaces as well:

```bash
KUBECONTEXT=k3d-k3s-default REMOVE_NAMESPACES=true ./scripts/uninstall-workshop-stack.sh
```

The uninstall script now also removes:

- the demo app resources in `demo`
- residual Argo CD and Prometheus Operator CRDs
- stuck finalizers on workshop namespaces
