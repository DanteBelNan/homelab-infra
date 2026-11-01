# 1. Despliegue del Docker Registry local en el namespace infra-core
resource "helm_release" "docker_registry" {
  name       = "registry"
  repository = "https://helm.twun.io"
  chart      = "docker-registry"
  namespace  = "infra-core"
  version    = "2.2.2" # Versión estable en este repositorio

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  
  set {
    name  = "persistence.enabled"
    value = "true"
  }
}

# 2. Despliegue del Stack de Observabilidad (Prometheus + Grafana) en el namespace observability
resource "helm_release" "kube_prometheus_stack" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "observability"
  version          = "60.10.0"
  create_namespace = false

  set {
    name  = "grafana.enabled"
    value = "true"
  }
  
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
}