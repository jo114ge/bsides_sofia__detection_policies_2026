terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

resource "kubernetes_namespace" "demo" {
  metadata {
    name = var.demo_namespace

    labels = {
      owner = "platform-team"
      env   = "workshop"
    }
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = "kyverno"
  }
}

resource "kubernetes_config_map" "workshop_metadata" {
  metadata {
    name      = "workshop-metadata"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  data = {
    cluster_name = var.cluster_name
    owner_team   = "platform-team"
    mode         = "policy-as-detection"
  }
}

