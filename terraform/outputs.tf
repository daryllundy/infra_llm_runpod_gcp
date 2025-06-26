output "endpoint" {
  description = "URL for the LLM service"
  value       = "http://${google_compute_instance.llm.network_interface[0].access_config[0].nat_ip}:8000"
}
