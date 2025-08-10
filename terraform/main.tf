# Data source per kubeconfig generato da Ansible
data "local_file" "kubeconfig" {
  filename   = "../kubeconfig"
  depends_on = [null_resource.wait_for_cluster]
}

# Risorsa per attendere che il cluster sia pronto
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for kubeconfig to be available..."
      while [ ! -f ../kubeconfig ]; do
        echo "Kubeconfig not found, waiting..."
        sleep 10
      done
      echo "Kubeconfig found, cluster is ready!"
    EOT
  }
}

# Provider Kubernetes
provider "kubernetes" {
  config_path = "../kubeconfig"
}

# Provider Helm
provider "helm" {
  kubernetes {
    config_path = "../kubeconfig"
  }
}

# Crea il namespace kiratech-test
resource "kubernetes_namespace" "kiratech_test" {
  metadata {
    name = "kiratech-test"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = "test"
    }
  }
}

# Network Policy corretta per il namespace
resource "kubernetes_network_policy" "kiratech_test_network_policy" {
  metadata {
    name      = "kiratech-test-network-policy"
    namespace = kubernetes_namespace.kiratech_test.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.kiratech_test.metadata[0].name
          }
        }
      }
    }

    egress {
      # Permetti tutto il traffico in uscita
    }
  }
}

# ConfigMap per kube-bench job
resource "kubernetes_config_map" "kube_bench_config" {
  metadata {
    name      = "kube-bench-config"
    namespace = kubernetes_namespace.kiratech_test.metadata[0].name
  }

  data = {
    "kube-bench.sh" = file("${path.module}/scripts/kube-bench.sh")
  }
}

# Job per eseguire kube-bench security benchmark
resource "kubernetes_job" "kube_bench" {
  metadata {
    name      = "kube-bench-security-scan"
    namespace = kubernetes_namespace.kiratech_test.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "kube-bench"
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "kube-bench"
          image = "aquasec/kube-bench:v0.7.1"

          command = ["/bin/sh"]
          args    = ["/scripts/kube-bench.sh"]

          volume_mount {
            name       = "kube-bench-config"
            mount_path = "/scripts"
          }

          volume_mount {
            name       = "var-lib-etcd"
            mount_path = "/var/lib/etcd"
            read_only  = true
          }

          volume_mount {
            name       = "var-lib-kubelet"
            mount_path = "/var/lib/kubelet"
            read_only  = true
          }

          volume_mount {
            name       = "etc-kubernetes"
            mount_path = "/etc/kubernetes"
            read_only  = true
          }

          volume_mount {
            name       = "usr-bin"
            mount_path = "/usr/local/mount-from-host/bin"
            read_only  = true
          }
        }

        volume {
          name = "kube-bench-config"
          config_map {
            name         = kubernetes_config_map.kube_bench_config.metadata[0].name
            default_mode = "0755"
          }
        }

        volume {
          name = "var-lib-etcd"
          host_path {
            path = "/var/lib/etcd"
          }
        }

        volume {
          name = "var-lib-kubelet"
          host_path {
            path = "/var/lib/kubelet"
          }
        }

        volume {
          name = "etc-kubernetes"
          host_path {
            path = "/etc/kubernetes"
          }
        }

        volume {
          name = "usr-bin"
          host_path {
            path = "/usr/bin"
          }
        }

        host_network = true
        host_pid     = true

        node_selector = {
          "node-role.kubernetes.io/control-plane" = ""
        }

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      }
    }

    backoff_limit = 4
  }
}

# RBAC per metrics server
resource "kubernetes_cluster_role" "metrics_server" {
  metadata {
    name = "system:metrics-server"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "nodes/stats", "namespaces", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "metrics_server" {
  metadata {
    name = "system:metrics-server"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.metrics_server.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "metrics-server"
    namespace = "kube-system"
  }
}

# Service Account per metrics server
resource "kubernetes_service_account" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
  }
}

# Deployment del metrics server
resource "kubernetes_deployment" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels = {
      k8s-app = "metrics-server"
    }
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "metrics-server"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app = "metrics-server"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.metrics_server.metadata[0].name

        container {
          name  = "metrics-server"
          image = "registry.k8s.io/metrics-server/metrics-server:v0.7.0"

          args = [
            "--cert-dir=/tmp",
            "--secure-port=4443",
            "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
            "--kubelet-use-node-status-port",
            "--metric-resolution=15s",
            "--kubelet-insecure-tls"
          ]

          port {
            name           = "https"
            container_port = 4443
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }

          volume_mount {
            name       = "tmp-dir"
            mount_path = "/tmp"
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 1000
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }
        }

        volume {
          name = "tmp-dir"
          empty_dir {}
        }

        priority_class_name = "system-cluster-critical"
      }
    }
  }
}

# Service per metrics server
resource "kubernetes_service" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels = {
      "kubernetes.io/name"            = "Metrics-server"
      "kubernetes.io/cluster-service" = "true"
    }
  }

  spec {
    selector = {
      k8s-app = "metrics-server"
    }

    port {
      name        = "https"
      port        = 443
      protocol    = "TCP"
      target_port = "https"
    }
  }
}
