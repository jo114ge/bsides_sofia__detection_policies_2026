output "demo_namespace" {
  value       = kubernetes_namespace.demo.metadata[0].name
  description = "Namespace used by the workshop application."
}

output "cluster_name" {
  value       = var.cluster_name
  description = "Cluster label used in alerts and dashboards."
}

