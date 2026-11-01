resource "kubernetes_namespace" "homelab_ns" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.value
    labels = {
      "managed-by" = "terraform"
      "homelab"    = "true"
    }
  }
}