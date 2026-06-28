output "namespace" {
  description = "Namespace Atlantis is deployed in"
  value       = kubernetes_namespace.atlantis.metadata[0].name
}

output "release_name" {
  description = "Name of the Atlantis Helm release"
  value       = helm_release.atlantis.name
}

output "release_status" {
  description = "Status of the Atlantis Helm release"
  value       = helm_release.atlantis.status
}

output "webhook_hint" {
  description = "How to find the webhook URL once the load balancer is provisioned"
  value       = "Run: kubectl -n ${var.namespace} get svc atlantis -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' — then set the GitHub webhook to http://<hostname>/events"
}
