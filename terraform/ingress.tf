resource "kubernetes_ingress_v1" "grafana_ingress" {
  metadata {
    name      = "grafana-ingress"
    namespace = "observability"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      host = "grafana.homelab"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}