output "namespace_name" {
  description = "Nome del namespace creato"
  value       = kubernetes_namespace.kiratech_test.metadata[0].name
}

output "kube_bench_job_name" {
  description = "Nome del job kube-bench per il security benchmark"
  value       = kubernetes_job.kube_bench.metadata[0].name
}

output "cluster_info" {
  description = "Informazioni del cluster"
  value = {
    namespace = kubernetes_namespace.kiratech_test.metadata[0].name
    labels    = kubernetes_namespace.kiratech_test.metadata[0].labels
  }
}

output "security_benchmark_command" {
  description = "Comando per verificare i risultati del benchmark di sicurezza"
  value       = "kubectl logs job/${kubernetes_job.kube_bench.metadata[0].name} -n ${kubernetes_namespace.kiratech_test.metadata[0].name}"
}
