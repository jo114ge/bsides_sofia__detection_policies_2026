variable "kubeconfig_path" {
  description = "Path to kubeconfig."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context name."
  type        = string
  default     = "k3d-workshop"
}

variable "cluster_name" {
  description = "Logical cluster name for dashboards and alerts."
  type        = string
  default     = "workshop-cluster"
}

variable "demo_namespace" {
  description = "Namespace for the demo application."
  type        = string
  default     = "demo"
}

