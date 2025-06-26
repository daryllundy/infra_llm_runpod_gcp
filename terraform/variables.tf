variable "project_id" {
  description = "GCP project ID"
}

variable "region" {
  description = "GCP region"
  default     = "us-central1"
}

variable "MODEL_ID" {
  description = "Model ID for vLLM container"
  default     = "meta-llama/Llama-3-8B-Instruct.Q4_K_M.gguf"
}

variable "API_KEY" {
  description = "API key for vLLM service"
  default     = "your-secret-api-key" # Replace with a secure key
}
