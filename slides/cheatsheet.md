---
marp: true
theme: default
paginate: true
backgroundColor: "#0f1117"
color: "#e2e8f0"
style: |
  section {
    font-family: 'JetBrains Mono', 'Fira Code', monospace;
    font-size: 0.85rem;
  }
  h1 { color: #7dd3fc; font-size: 1.6rem; margin-bottom: 0.3em; }
  h2 { color: #7dd3fc; font-size: 1.2rem; margin-bottom: 0.2em; }
  h3 { color: #94a3b8; font-size: 0.95rem; margin-bottom: 0.1em; }
  code { background: #1e293b; color: #e2e8f0; padding: 0.1em 0.3em; border-radius: 3px; }
  pre { background: #1e293b; border-left: 3px solid #7dd3fc; padding: 0.6em 1em; border-radius: 4px; margin: 0.3em 0; }
  pre code { background: transparent; padding: 0; }
  strong { color: #fbbf24; }
  em { color: #86efac; font-style: normal; }
  table { font-size: 0.75rem; }
  th { background: #1e293b; color: #7dd3fc; }
  td { background: #0f172a; }
---

# Workshop Cheatsheet
## Policy-as-Detection for Kubernetes · BSides Sofia 2026

---

# Cluster & Context

```bash
# Set context for all commands
export CTX=k3d-workshop

# Verify cluster is up
kubectl --context $CTX get nodes

# All namespaces overview
kubectl --context $CTX get all -n demo
kubectl --context $CTX get all -n argocd
kubectl --context $CTX get all -n monitoring
kubectl --context $CTX get all -n kyverno
```

---

# Port-Forwards

```bash
# ArgoCD UI  →  http://localhost:8080
kubectl --context k3d-workshop port-forward svc/argocd-server -n argocd 8080:443

# Grafana    →  http://localhost:3000  (admin / workshop)
kubectl --context k3d-workshop port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

# Prometheus →  http://localhost:9090
kubectl --context k3d-workshop port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090

# Alertmanager → http://localhost:9093
kubectl --context k3d-workshop port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093
```

---

# ArgoCD

```bash
# Get admin password
kubectl --context k3d-workshop -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

# List apps
kubectl --context k3d-workshop -n argocd get app

# Force hard refresh (re-reads git HEAD)
kubectl --context k3d-workshop -n argocd patch app kyverno-policies \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

kubectl --context k3d-workshop -n argocd patch app demo-app \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Watch sync status live
watch kubectl --context k3d-workshop -n argocd get app
```

---

# Kyverno — Policies

```bash
# List namespace-scoped policies in demo
kubectl --context k3d-workshop get policy -n demo

# Describe a specific policy
kubectl --context k3d-workshop describe policy disallow-latest -n demo

# Watch policy status
kubectl --context k3d-workshop get policy -n demo -w

# Check Kyverno pods are healthy
kubectl --context k3d-workshop get pods -n kyverno
```

---

# Kyverno — PolicyReports

```bash
# All reports in demo namespace
kubectl --context k3d-workshop get policyreport -n demo

# Show only FAILING reports
kubectl --context k3d-workshop get policyreport -n demo -o json | \
  jq '.items[] | select(.summary.fail > 0) | {name: .metadata.name, fail: .summary.fail}'

# Full detail of all failures
kubectl --context k3d-workshop get policyreport -n demo -o json | \
  jq '[.items[].results[] | select(.result == "fail") | {policy, rule, message}]'

# Watch reports update live
kubectl --context k3d-workshop get policyreport -n demo -w

# Delete stale reports (after cleaning up a scenario)
kubectl --context k3d-workshop delete policyreport -n demo --all
```

---

# Kyverno — Metrics

```bash
# Raw Kyverno metrics (pipe to grep for policy results)
kubectl --context k3d-workshop port-forward svc/kyverno-svc-metrics -n kyverno 8000:8000 &
curl -s http://localhost:8000/metrics | grep kyverno_policy_results_total | grep 'rule_result="fail"'

# Same via Prometheus API
curl -s 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=kyverno_policy_results_total{rule_result="fail",resource_namespace="demo"}' \
  | jq '.data.result[] | {policy: .metric.policy_name, value: .value[1]}'
```

---

# Demo App — Inspect Current State

```bash
# See what image and securityContext is deployed
kubectl --context k3d-workshop get deployment demo-app -n demo \
  -o jsonpath='{.spec.template.spec.containers[0]}' | jq '{image, resources, securityContext}'

# See host namespace settings
kubectl --context k3d-workshop get deployment demo-app -n demo \
  -o jsonpath='{.spec.template.spec}' | jq '{hostNetwork, hostPID, hostIPC}'

# Watch rollout after a patch
kubectl --context k3d-workshop rollout status deployment/demo-app -n demo
```

---

# GitOps Flow — Activate a Scenario

```bash
# 1. Edit the policy kustomization (uncomment a policy)
code policies/kyverno/kustomization.yaml

# 2. Edit the app kustomization (uncomment a bad patch)
code apps/demo-app/overlays/workshop/kustomization.yaml

# 3. Commit and push
git add policies/kyverno/kustomization.yaml \
      apps/demo-app/overlays/workshop/kustomization.yaml
git commit -m "demo: activate scenario X"
git push

# 4. Watch ArgoCD reconcile (30s auto-sync)
watch kubectl --context k3d-workshop -n argocd get app

# 5. Watch PolicyReports update
kubectl --context k3d-workshop get policyreport -n demo -w
```

---

# GitOps Flow — Reset to Baseline

```bash
# Comment out all patches in both kustomization files, then:
git add policies/kyverno/kustomization.yaml \
      apps/demo-app/overlays/workshop/kustomization.yaml
git commit -m "demo: reset to baseline"
git push

# Clean up stale PolicyReports
kubectl --context k3d-workshop delete policyreport -n demo --all
```

---

# Scenario Reference

| # | Policy | Bad Patch | What breaks |
|---|--------|-----------|-------------|
| 1 | `disallow-latest` | `bad-image-patch.yaml` | `nginx:latest` tag |
| 2 | `require-requests` | `bad-resources-patch.yaml` | No CPU/mem requests |
| 3 | `disallow-privileged` | `bad-privileged-patch.yaml` | `privileged: true` |
| 4 | `disallow-run-as-root` | `bad-run-as-root-patch.yaml` | `runAsUser: 0` |
| 5 | `restrict-image-registries` | `bad-image-registry-patch.yaml` | `docker.io/library/nginx` |
| 6 | `disallow-host-namespaces` | `bad-host-namespaces-patch.yaml` | `hostNetwork: true` |

Both files to edit for scenarios 3–6:
- `policies/kyverno/kustomization.yaml` (uncomment policy)
- `apps/demo-app/overlays/workshop/kustomization.yaml` (uncomment patch)

---

# Prometheus — Check Alerts

```bash
# List active alerts via API
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {name: .labels.alertname, state: .state, policy: .labels.policy_name}'

# Check PrometheusRule is loaded
kubectl --context k3d-workshop get prometheusrule -n monitoring

# Describe the rule
kubectl --context k3d-workshop describe prometheusrule kyverno-policy-violations -n monitoring

# Check rule evaluation in Prometheus UI
# http://localhost:9090  →  Alerts tab
```

---

# Alertmanager

```bash
# List firing alerts
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | {name: .labels.alertname, policy: .labels.policy_name, ns: .labels.resource_namespace}'

# UI: http://localhost:9093
```

---

# Grafana

```bash
# URL:  http://localhost:3000
# User: admin
# Pass: workshop

# Check dashboard ConfigMap is loaded
kubectl --context k3d-workshop get configmap -n monitoring -l grafana_dashboard=1

# Useful panels in "Kyverno Policy Violations" dashboard:
#   - Total violations by policy (bar chart)
#   - Violation timeline (time series)
#   - Raw violations table
```

---

# Troubleshooting

```bash
# Kyverno admission webhook errors?
kubectl --context k3d-workshop logs -n kyverno -l app.kubernetes.io/name=kyverno --tail=50

# Policy not applying?
kubectl --context k3d-workshop describe policy <name> -n demo

# ArgoCD stuck OutOfSync?
kubectl --context k3d-workshop -n argocd patch app <name> \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# PolicyReport not updating?
kubectl --context k3d-workshop delete policyreport -n demo --all
# Kyverno will regenerate within ~30s

# Check Kyverno background scan is running
kubectl --context k3d-workshop get policy -n demo -o json | \
  jq '.items[] | {name: .metadata.name, background: .spec.background}'
```
