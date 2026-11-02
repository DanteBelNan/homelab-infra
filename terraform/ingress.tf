resource "kubernetes_ingress_v1" "grafana_ingress" {
  depends_on = [helm_release.ingress_nginx]

  metadata {
    name      = "grafana-ingress"
    namespace = "observability"
  }

  spec {
    ingress_class_name = "nginx"

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