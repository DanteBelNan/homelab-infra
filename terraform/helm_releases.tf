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

# 3. Despliegue del Nginx Ingress Controller en el namespace infra-core
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "infra-core"
  create_namespace = false

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Forzamos a que Nginx procese EXCLUSIVAMENTE los Ingress que tengan ingressClassName: nginx
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

  # Indicamos explícitamente qué namespaces debe vigilar para evitar ruidos de Traefik
  set_list {
    name  = "controller.watchNamespaces"
    value = ["observability", "infra-core"]
  }
}

# 4. Despliegue de Grafana Loki para centralización de logs
resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  namespace        = "observability"
  create_namespace = false

  set {
    name  = "loki.enabled"
    value = "true"
  }

  set {
    name  = "promtail.enabled"
    value = "true"
  }
}
# 5. Despliegue del OpenTelemetry Collector para métricas y trazas de aplicaciones
resource "helm_release" "otel_collector" {
  name             = "otel-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  namespace        = "observability"
  create_namespace = false

  set {
    name  = "mode"
    value = "deployment"
  }

  # Requerido por el chart en versiones recientes
  set {
    name  = "image.repository"
    value = "otel/opentelemetry-collector-contrib"
  }

  set {
    name  = "config.receivers.otlp.protocols.grpc.endpoint"
    value = "0.0.0.0:4317"
  }

  set {
    name  = "config.receivers.otlp.protocols.http.endpoint"
    value = "0.0.0.0:4318"
  }

  # Exportador hacia el Prometheus del clúster
  set {
    name  = "config.exporters.prometheus.endpoint"
    value = "0.0.0.0:8889"
  }

  set {
    name  = "config.service.pipelines.metrics.receivers[0]"
    value = "otlp"
  }

  set {
    name  = "config.service.pipelines.metrics.exporters[0]"
    value = "prometheus"
  }
}