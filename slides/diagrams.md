---
marp: true
theme: default
paginate: true
backgroundColor: "#0f1117"
color: "#e2e8f0"
style: |
  section {
    font-family: 'JetBrains Mono', 'Fira Code', monospace;
    font-size: 0.78rem;
    padding: 2rem 2.5rem;
  }
  h1 { color: #7dd3fc; font-size: 1.5rem; margin-bottom: 0.4em; border-bottom: 1px solid #1e40af; padding-bottom: 0.2em; }
  h2 { color: #93c5fd; font-size: 1.1rem; margin: 0.6em 0 0.3em; }
  h3 { color: #64748b; font-size: 0.85rem; margin: 0.3em 0 0.1em; }
  code { background: #1e293b; color: #7dd3fc; padding: 0.1em 0.4em; border-radius: 3px; font-size: 0.85em; }
  pre { background: #0d1117; border-left: 3px solid #1d4ed8; padding: 0.7em 1em; border-radius: 4px; margin: 0.4em 0; font-size: 0.72rem; line-height: 1.5; }
  pre code { background: transparent; padding: 0; color: #e2e8f0; font-size: inherit; }
  strong { color: #fbbf24; }
  em { color: #86efac; font-style: normal; }
  p { margin: 0.3em 0; line-height: 1.6; }
  ul { margin: 0.2em 0; padding-left: 1.2em; }
  li { margin: 0.15em 0; }
  table { font-size: 0.72rem; width: 100%; border-collapse: collapse; }
  th { background: #1e293b; color: #7dd3fc; padding: 0.4em 0.7em; }
  td { background: #0f172a; padding: 0.3em 0.7em; border-top: 1px solid #1e293b; }
  .label { display: inline-block; background: #1e3a5f; color: #7dd3fc; border-radius: 3px; padding: 0.1em 0.5em; font-size: 0.7rem; margin-right: 0.3em; }
---

# Reference Diagrams
## Policy-as-Detection for Kubernetes · BSides Sofia 2026

---

# Diagram Index

| # | Title |
|---|-------|
| 1 | k3d Cluster — Local Docker Setup |
| 2 | Kubernetes Concepts |
| 3 | Apps and Policies — Signal Map |
| 4 | Full Pipeline Architecture |
| 5 | Argo CD — How It Works |
| 6 | Kyverno — How It Works |
| 7 | Prometheus Alert Rule |
| 8 | Grafana — How It Works |
| 9 | Helm vs Kustomize |
| 10 | SIEM Integration |
| 11 | Terraform — Bootstrap Layers |

---

# 1 · k3d Cluster — Local Docker Setup

```
Your Machine
┌──────────────────────────────────────────────────────────────────┐
│  kubectl / helm / k3d CLI           KUBECONTEXT: k3d-workshop    │
└──────────────────────────┬───────────────────────────────────────┘
                           │
         ┌─────────────────┼───────────────────┬──────────────┐
         ▼                 ▼                   ▼              ▼
  ┌────────────┐  ┌──────────────┐  ┌──────────────┐  ┌───────────┐
  │ server-0   │  │  agent-0     │  │  serverlb    │  │  tools    │
  │            │  │              │  │              │  │           │
  │ Control    │  │ Worker Node  │  │ Load Balancer│  │ Init      │
  │ Plane      │  │              │  │              │  │ helper    │
  │            │  │ Runs pods:   │  │ :80  :443    │  │ (exits    │
  │ API server │  │ demo-app     │  │ :8443        │  │ after     │
  │ etcd       │  │ kyverno      │  │              │  │ setup)    │
  │ scheduler  │  │ argocd       │  │              │  │           │
  │            │  │ prometheus   │  │              │  │           │
  └────────────┘  └──────────────┘  └──────────────┘  └───────────┘

  Namespaces                         Port-forwards (manual)
  ──────────────────────────────     ──────────────────────────────────
  argocd      GitOps controller      localhost:8080 → argocd-server
  kyverno     Policy engine          localhost:3000 → grafana
  monitoring  Prometheus + Grafana   localhost:9090 → prometheus
  demo        Workshop workloads     localhost:9093 → alertmanager
```

---

# 2 · Kubernetes — Key Concepts

```
IMAGE                              POD                          DEPLOYMENT
─────────────────────────          ────────────────────────     ──────────────────────────
Read-only snapshot of app          Smallest deployable unit     Manages a ReplicaSet
stored in a registry               One or more containers       Handles rolling updates

registry ──pull──▶ container       ┌──────────────────────┐    ┌──────────────────────┐
                                   │  Pod                 │    │  Deployment          │
nginx:latest  ← unknown version    │  ┌────────────────┐  │    │  replicas: 1         │
nginx:1.29.1  ← reproducible       │  │ web container  │  │    │  template:           │
                                   │  │ image: nginx   │  │    │    spec:             │
                                   │  │ port: 8080     │  │    │      containers:     │
                                   │  └────────────────┘  │    │        - name: web   │
                                   │  IP: 10.42.0.5       │    └──────────────────────┘
                                   └──────────────────────┘
```

```
NAMESPACE                          KUSTOMIZE BASE + OVERLAY
─────────────────────────          ──────────────────────────────────────────
Logical isolation boundary         base/              overlays/workshop/
Each namespace has its own         deployment.yaml    kustomization.yaml  ← patches
  Policies, Quotas, RBAC           service.yaml       bad-image-patch.yaml

demo       ← our workloads         ArgoCD reads overlay → applies result to cluster
kyverno    ← policy engine         Uncomment a patch → bad config deployed via Git
monitoring ← observability
```

---

# 3 · Apps and Policies — Signal Map

```
  demo-app (baseline — clean state)
  ┌────────────────────────────────────────────────────────────────┐
  │  image:        nginxinc/nginx-unprivileged:1.29.1  ✓ pinned   │
  │  cpu requests: 100m / limits: 250m                 ✓ declared │
  │  mem requests: 128Mi / limits: 256Mi               ✓ declared │
  │  runAsNonRoot: true                                ✓ secure   │
  │  privileged:   false                               ✓ secure   │
  │  hostNetwork:  false                               ✓ isolated │
  └────────────────────────────────────────────────────────────────┘
```

| Scenario | Policy | What breaks | Severity | Signal |
|----------|--------|-------------|----------|--------|
| 1 | `disallow-latest` | `image: nginx:latest` | medium | Supply chain / traceability |
| 2 | `require-requests` | no CPU/mem requests | medium | Reliability / cost governance |
| 3 | `disallow-privileged` | `privileged: true` | **high** | Container escape risk |
| 4 | `disallow-run-as-root` | `runAsUser: 0` | **high** | Privilege escalation surface |
| 5 | `restrict-image-registries` | `docker.io/library/nginx` | **high** | Untrusted code in cluster |
| 6 | `disallow-host-namespaces` | `hostNetwork: true` | **critical** | Sandbox boundary broken |

---

# 4 · Full Pipeline Architecture

```
  Developer
     │ git push
     ▼
  ┌──────────────────────────────────────────────┐
  │  Git Repository                              │
  │  apps/demo-app/    policies/kyverno/         │
  │  observability/    terraform/                │
  └──────────────┬─────────────────┬────────────┘
                 │ sync            │ bootstrap (once)
                 ▼                 ▼
  ┌──────────────────────────────────────────────┐
  │  Kubernetes Cluster                          │
  │                                              │
  │  ArgoCD ──apply──▶ Kyverno Policy Engine     │
  │                          │                  │
  │                   Audit mode                 │
  │                    /         \               │
  │              allowed       allowed           │
  │                               │              │
  │                         PolicyReport         │
  │                         result: fail         │
  └──────────────────────────┬───────────────────┘
                             │ kyverno_policy_results_total{rule_result="fail"}
                             ▼
  ┌──────────────────────────────────────────────┐
  │  Observability Stack                         │
  │                                              │
  │  Prometheus ──scrape──▶ PrometheusRule        │
  │      │                  rate([5m]) > 0        │
  │      │                       │               │
  │      ▼                       ▼               │
  │  Grafana               Alertmanager          │
  │  Dashboard             severity: warning     │
  └──────────────────┬───────────────────────────┘
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
     Ticket/Issue           Notification
     (Jira/GitHub)          (Slack/Email)
          │
          │ fix committed to Git
          ▼
     ArgoCD reconciles → violation clears → alert resolves
```

---

# 5 · Argo CD — How It Works

```
  DESIRED STATE (Git)                     ACTUAL STATE (Cluster)
  ┌────────────────────────────┐          ┌────────────────────────────┐
  │ apps/demo-app/             │          │ namespace: demo            │
  │   deployment.yaml          │          │   Deployment/demo-app      │
  │   service.yaml             │          │     image: nginx:1.29.1    │
  │ policies/kyverno/          │          │                            │
  │   disallow-latest.yaml     │          │ namespace: demo            │
  │   require-requests.yaml    │          │   Policy/disallow-latest   │
  └────────────┬───────────────┘          └───────────────┬────────────┘
               │                                          │
               │          ┌───────────────────┐           │
               └─────────▶│     Argo CD       │◀──────────┘
                 watches  │  1. Detects diff   │ reads cluster
                          │  2. Reconciles     │
                          │  3. Reports health │
                          └───────────────────┘

  Reconciliation states:
  ┌──────────┬──────────────────────────────────────────────────────┐
  │ Synced   │ Git == Cluster. Nothing to do.                       │
  │ OutOfSync│ Diff detected. Will apply changes.                   │
  │ Syncing  │ Applying changes now.                                │
  │ Healthy  │ All pods Running, no errors.                         │
  │ Degraded │ Pod crashlooping or ImagePullBackOff.                │
  └──────────┴──────────────────────────────────────────────────────┘

  syncPolicy:                  prune: true   → deletes resources removed from Git
    automated:                 selfHeal: true → reverts manual kubectl edits
      prune: true
      selfHeal: true           Git is the only source of truth.
```

---

# 6 · Kyverno — Admission vs Background Scan

```
  1. ADMISSION (new resources)                2. BACKGROUND SCAN (existing resources)
  ────────────────────────────────            ─────────────────────────────────────────
  kubectl apply / ArgoCD sync                 Kyverno re-evaluates ALL resources
           │                                  against ALL active policies every ~1min
           ▼
     API Server                               Catches violations on resources deployed
           │                                  BEFORE the policy existed.
     AdmissionReview ──▶ Kyverno
                              │
              validationFailureAction?
              ┌───────────────┴──────────────┐
           Enforce                         Audit
              │                              │
         violation?                    violation?
         /      \                      /      \
       YES       NO                  YES       NO
        │         │                   │         │
     REJECT    ALLOW               ALLOW     ALLOW
     (403)        │                   │
                  │             PolicyReport
                  │             result: fail
                  └─────────────────▶ metric++

  In this workshop: all policies use Audit.
  The deploy always goes through. The violation is always recorded.
```

---

# 6 · Kyverno — Policy Anatomy

```yaml
apiVersion: kyverno.io/v1
kind: Policy           # namespace-scoped → only evaluates resources in 'demo'
metadata:
  name: disallow-latest
  namespace: demo
spec:
  validationFailureAction: Audit      # record but do not block
  background: true                    # also scan existing resources

  rules:
    - name: require-pinned-image-tag-deployment
      match:
        any:
          - resources:
              kinds: [Deployment]     # what resource types to check

      validate:
        message: "Images must not use the latest tag."
        pattern:
          spec:
            template:
              spec:
                containers:
                  - image: "!*:latest"   # any image NOT ending in :latest → PASS
```

---

# 7 · Prometheus — Alert Rule

```
  PrometheusRule evaluation loop (every 15s)
  ────────────────────────────────────────────────────────────────────────

  expr:  sum by (policy_name, resource_namespace) (
           rate(kyverno_policy_results_total{rule_result="fail", resource_namespace="demo"}[5m])
         ) > 0
         │                              │                              │
         │    rate([5m])                │                              │
         │    = violations/sec          │                              │
         │    over last 5 minutes       │                              │
         │    → drops to 0 when         │                              │
         │      scenario is reset       │                              │
         │                             filter                      threshold
         │                        only demo ns                    any rate > 0
         │
         for: 2m   ← must stay true for 2 min before firing

  Alert lifecycle:
  ┌──────────────────────────────────────────────────────────┐
  │  violation appears → rate > 0 → PENDING (2min timer)    │
  │                    → 2min elapsed  → FIRING              │
  │                    → scenario reset → rate drops to 0   │
  │                    → alert RESOLVES automatically        │
  └──────────────────────────────────────────────────────────┘

  Labels on the firing alert:
    alertname="KyvernoPolicyViolationDetected"
    policy_name="disallow-latest"
    resource_namespace="demo"
    severity="warning"
    team="platform"
```

---

# 8 · Grafana — How It Works

```
  Data source                 Dashboard                  User
  ──────────────              ──────────────────────     ──────────
  Prometheus                  ConfigMap in cluster       Browser
  (time-series DB)            label: grafana_dashboard=1 http://localhost:3000

  kyverno_policy_results_total
           │
           │  PromQL query
           ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  Panel: Violations by Policy (bar chart)                        │
  │                                                                  │
  │  disallow-latest         ████░░░░░░  2                          │
  │  require-requests        ██░░░░░░░░  1                          │
  │  disallow-privileged     ████████░░  4                          │
  │  restrict-image-reg      ████████░░  4                          │
  │  disallow-host-ns        ██████████  5                          │
  └──────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │  Panel: Violation Timeline (time series)                        │
  │                                                                  │
  │  5 ┤                              ╭───────                      │
  │  4 ┤                         ╭───╯                              │
  │  3 ┤                    ╭───╯                                   │
  │  2 ┤               ╭───╯                                        │
  │  1 ┤          ╭───╯           scenario activated                │
  │  0 ┼──────────╯                                                 │
  └──────────────────────────────────────────────────────────────────┘
```

---

# 9 · Helm vs Kustomize

```
  HELM                                   KUSTOMIZE
  ─────────────────────────────────      ──────────────────────────────────────
  Package manager for Kubernetes         Overlay / patching system

  Uses templates with values:            Uses base + patch files:

  deployment.yaml.tmpl                   base/deployment.yaml      ← clean YAML
  {{ .Values.image.tag }}                overlays/workshop/        ← patches only
  {{ .Values.replicas }}                   kustomization.yaml
                                           bad-image-patch.yaml

  helm install --set image.tag=1.29.1    kustomize build overlays/workshop/
  helm upgrade --set image.tag=1.30.0    → merges base + patches

  Good for: distributing reusable        Good for: environment-specific config
  charts (prometheus, kyverno, argocd)   without duplicating base manifests

  In this workshop:
  ┌──────────────────────────────────────────────────────────────────┐
  │  Helm         → installs kyverno, prometheus, argocd, grafana   │
  │  Kustomize    → manages demo-app config + bad scenario patches   │
  │  ArgoCD       → syncs both from Git to the cluster              │
  └──────────────────────────────────────────────────────────────────┘
```

---

# 10 · SIEM Integration

```
  Kubernetes Cluster                External Systems
  ──────────────────────────        ──────────────────────────────────────────

  Kyverno PolicyReport              Option A — Alertmanager webhook
       │                                 Alertmanager ──POST──▶ ticket-adapter
       │ metric                          {                        │
       ▼                                   "alertname": "...",   ▼
  Prometheus                               "policy_name": "...", Jira / GitHub
       │                                   "severity": "warning" Issue / PagerDuty
       │ alert                           }
       ▼
  Alertmanager                      Option B — Log shipping
                                         kubectl logs (kyverno) ──▶ Loki / Elastic
                                         PolicyReport events    ──▶ SIEM (Splunk, QRadar)

                                    Option C — Direct API pull
                                         SIEM polls Prometheus API every 1min
                                         GET /api/v1/query?query=kyverno_policy_results_total

  Alert payload includes:
  ┌────────────────────────────────────────────────────────────┐
  │  policy_name:         disallow-latest                     │
  │  resource_namespace:  demo                                │
  │  severity:            warning                             │
  │  team:                platform                            │
  │  description:         Policy has active failures in demo  │
  └────────────────────────────────────────────────────────────┘

  The namespace label (owner=platform-team) enriches every alert
  with team ownership — no manual triage needed.
```

---

# 11 · Terraform — Bootstrap Layers

```
  What Terraform does in this workshop (bootstrap only, run once)
  ────────────────────────────────────────────────────────────────

  terraform apply
       │
       ▼
  Layer 1: Namespaces
  ┌─────────────────────────────────────────────────────┐
  │  namespace: demo        label: owner=platform-team  │
  │  namespace: argocd      label: managed-by=terraform │
  │  namespace: kyverno                                 │
  │  namespace: monitoring                              │
  └─────────────────────────────────────────────────────┘
       │
       ▼
  Layer 2: ConfigMap (metadata)
  ┌─────────────────────────────────────────────────────┐
  │  workshop-metadata (in demo namespace)              │
  │    workshop: bsides-sofia-2026                      │
  │    track: policy-as-detection                       │
  └─────────────────────────────────────────────────────┘
       │
       ▼
  Layer 3: Helm releases (via helm_release resource)
  ┌─────────────────────────────────────────────────────┐
  │  kyverno      → kyverno/kyverno chart               │
  │  argocd       → argo/argo-cd chart                  │
  │  prometheus   → prometheus-community/kube-prometheus│
  └─────────────────────────────────────────────────────┘
       │
       ▼
  Layer 4: ArgoCD Applications (via kubectl_manifest)
  ┌─────────────────────────────────────────────────────┐
  │  Application: demo-app          → apps/demo-app/    │
  │  Application: kyverno-policies  → policies/kyverno/ │
  │  Application: observability     → observability/    │
  └─────────────────────────────────────────────────────┘

  After terraform apply → ArgoCD takes over → Git is source of truth
  Terraform is NOT re-run during the workshop.
```
