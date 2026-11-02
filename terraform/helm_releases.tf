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

  values = [<<-EOT
    grafana:
      enabled: true
      additionalDataSources:
        - name: Loki
          type: loki
          url: http://loki:3100
          access: proxy
          isDefault: false
        - name: Tempo
          type: tempo
          url: http://tempo:3100
          access: proxy
          isDefault: false

    prometheus:
      prometheusSpec:
        serviceMonitorSelectorNilUsesHelmValues: false
        # Habilitar remote write para recibir métricas del OTEL Collector
        enableRemoteWriteReceiver: true
  EOT
  ]
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

# 4. Despliegue de Grafana Loki (SingleBinary — reemplaza loki-stack deprecado)
resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  namespace        = "observability"
  create_namespace = false

  values = [<<-EOT
    deploymentMode: SingleBinary

    loki:
      commonConfig:
        replication_factor: 1
      storage:
        type: filesystem
      schemaConfig:
        configs:
          - from: "2024-01-01"
            store: tsdb
            object_store: filesystem
            schema: v13
            index:
              prefix: loki_index_
              period: 24h
      auth_enabled: false

    singleBinary:
      replicas: 1

    # Desactivar componentes distribuidos (no necesarios en single-node)
    read:
      replicas: 0
    write:
      replicas: 0
    backend:
      replicas: 0
  EOT
  ]
}

# 5. Despliegue de Promtail para scraping automático de logs de pods
resource "helm_release" "promtail" {
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  namespace        = "observability"
  create_namespace = false
  depends_on       = [helm_release.loki]

  set {
    name  = "config.clients[0].url"
    value = "http://loki:3100/loki/api/v1/push"
  }
}

# 6. Despliegue de Grafana Tempo para trazas distribuidas
# Disponible para cuando las apps comiencen a instrumentar trazas (OTLP → Tempo)
resource "helm_release" "tempo" {
  name             = "tempo"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "tempo"
  namespace        = "observability"
  create_namespace = false
  depends_on       = [helm_release.kube_prometheus_stack]

  values = [<<-EOT
    tempo:
      storage:
        trace:
          backend: local
          local:
            path: /var/tempo/traces
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: "0.0.0.0:4317"
            http:
              endpoint: "0.0.0.0:4318"
  EOT
  ]
}

# 7. Despliegue del OpenTelemetry Collector
# Recibe métricas y logs de apps instrumentadas (OTLP) y los enruta a Prometheus y Loki
# Recibe trazas y las enruta a Tempo
resource "helm_release" "otel_collector" {
  name             = "otel-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  namespace        = "observability"
  create_namespace = false
  timeout          = 600
  depends_on       = [helm_release.loki, helm_release.tempo, helm_release.kube_prometheus_stack]

  values = [<<-EOT
    mode: deployment

    image:
      repository: otel/opentelemetry-collector-contrib

    config:
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: "0.0.0.0:4317"
            http:
              endpoint: "0.0.0.0:4318"

      processors:
        batch: {}
        memory_limiter:
          check_interval: 1s
          limit_mib: 256

      exporters:
        prometheusremotewrite:
          endpoint: "http://monitoring-kube-prometheus-prometheus:9090/api/v1/write"
          tls:
            insecure: true
        # Loki soporta OTLP nativo desde v2.9 — el exporter "loki" fue removido de contrib
        otlphttp/loki:
          endpoint: "http://loki:3100/otlp"
          tls:
            insecure: true
        otlp/tempo:
          endpoint: "http://tempo:4317"
          tls:
            insecure: true

      service:
        pipelines:
          metrics:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [prometheusremotewrite]
          logs:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [otlphttp/loki]
          traces:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [otlp/tempo]
  EOT
  ]
}
