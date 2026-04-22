output "cluster_endpoint" {
  value = "https://${var.master_ip}:6443"
}

output "llm_api_endpoint" {
  value = "http://${var.master_ip}/api/generate"
  description = "The ingress endpoint to hit the TinyLlama model."
}