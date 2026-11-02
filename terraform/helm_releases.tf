# 1. Despliegue del Docker Registry local en el namespace infra-core
resource "helm_release" "docker_registry" {
  name       = "registry"
  repository = "https://twuni.github.io/docker-registry.helm"
  chart      = "docker-registry"
  namespace  = "infra-core"

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

# 3. Despliegue del Nginx Ingress Controller en el namespace infra-core (o uno dedicado como ingress-nginx)
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "infra-core"
  create_namespace = false

  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.scope.enabled"
    value = "true"
  }

  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
  }

  set {
    name  = "controller.ingressClass"
    value = "nginx"
  }
  
  set {
    name  = "controller.ingressClassResource.controllerValue"
    value = "k8s.io/ingress-nginx"
  }
}