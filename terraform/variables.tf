variable "namespaces" {
  type        = list(string)
  description = "Namespaces lógicos principales para el clúster del homelab"
  default     = ["paas-core", "observability", "infra-core", "apps"]
}