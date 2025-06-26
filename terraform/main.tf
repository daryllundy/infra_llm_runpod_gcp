provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_instance" "llm" {
  name         = "llm-a100-vllm"
  machine_type = "a2-highgpu-1g"
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20250415"
      size  = 100
    }
  }

  guest_accelerator {
    type  = "nvidia-tesla-a100"
    count = 1
  }

  scheduling {
    on_host_maintenance = "TERMINATE"
  }

  metadata_startup_script = <<-EOS
    #!/usr/bin/env bash
    set -e

    # Setup logging
    LOGFILE="/var/log/llm-startup.log"
    exec > >(tee -a $LOGFILE)
    exec 2>&1

    echo "$(date): Starting LLM service initialization..."

    # Function to log and exit on error
    log_error() {
        echo "$(date): ERROR: $1" | tee -a $LOGFILE
        exit 1
    }

    # Function to log success
    log_success() {
        echo "$(date): SUCCESS: $1" | tee -a $LOGFILE
    }

    # Update system and install Docker
    echo "$(date): Updating system packages..."
    apt-get update || log_error "Failed to update package lists"
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release || log_error "Failed to install required packages"

    # Add Docker's official GPG key
    echo "$(date): Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || log_error "Failed to add Docker GPG key"

    # Set up Docker repository
    echo "$(date): Setting up Docker repository..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null || log_error "Failed to setup Docker repository"

    # Install Docker Engine
    echo "$(date): Installing Docker Engine..."
    apt-get update || log_error "Failed to update package lists for Docker"
    apt-get install -y docker-ce docker-ce-cli containerd.io || log_error "Failed to install Docker Engine"
    log_success "Docker Engine installed"

    # Install NVIDIA Container Toolkit
    echo "$(date): Installing NVIDIA Container Toolkit..."
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add - || log_error "Failed to add NVIDIA Docker GPG key"
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list || log_error "Failed to setup NVIDIA Docker repository"
    apt-get update || log_error "Failed to update package lists for NVIDIA Docker"
    apt-get install -y nvidia-docker2 || log_error "Failed to install NVIDIA Container Toolkit"
    log_success "NVIDIA Container Toolkit installed"

    # Restart Docker to load nvidia runtime
    echo "$(date): Restarting Docker service..."
    systemctl restart docker || log_error "Failed to restart Docker service"
    log_success "Docker service restarted"

    # Verify Docker and GPU access
    echo "$(date): Verifying Docker installation..."
    docker --version || log_error "Docker verification failed"
    echo "$(date): Verifying GPU access..."
    nvidia-smi || log_error "GPU verification failed"
    log_success "Docker and GPU verification completed"

    # Cleanup any existing containers
    echo "$(date): Cleaning up any existing containers..."
    if docker ps -a | grep -q llm-service; then
        echo "$(date): Found existing llm-service container, removing..."
        docker stop llm-service 2>/dev/null || echo "$(date): Container was not running"
        docker rm llm-service 2>/dev/null || echo "$(date): Container was already removed"
        log_success "Existing container cleaned up"
    else
        echo "$(date): No existing containers found"
    fi

    # Clean up any dangling containers or images
    echo "$(date): Cleaning up dangling resources..."
    docker container prune -f 2>/dev/null || echo "$(date): No containers to prune"
    docker image prune -f 2>/dev/null || echo "$(date): No images to prune"

    # Start the LLM container
    echo "$(date): Starting LLM container..."
    if docker run -d \
      --gpus all \
      -p 8000:8000 \
      -e MODEL_ID=${var.MODEL_ID} \
      -e API_KEY=${var.API_KEY} \
      --restart unless-stopped \
      --name llm-service \
      --user 1000:1000 \
      --security-opt=no-new-privileges \
      --memory="16g" \
      --memory-swap="16g" \
      vllm/vllm-openai:latest \
      --api-key ${var.API_KEY}; then
        log_success "LLM container started"
    else
        log_error "Failed to start LLM container"
    fi

    # Log container status
    echo "$(date): Checking container status..."
    docker ps || log_error "Failed to check container status"

    # Wait a moment for container to initialize
    sleep 5

    # Check if container is still running
    if ! docker ps | grep -q llm-service; then
        echo "$(date): Container failed to start properly. Checking logs..."
        docker logs llm-service
        log_error "LLM container is not running"
    fi

    # Wait for service to be ready
    echo "$(date): Waiting for LLM service to be ready..."
    SERVICE_READY=false
    for i in {1..30}; do
      echo "$(date): Health check attempt $i/30..."
      if curl -f -H "Authorization: Bearer ${var.API_KEY}" http://localhost:8000/health 2>/dev/null; then
        echo "$(date): LLM service is ready!"
        SERVICE_READY=true
        break
      fi
      echo "$(date): Service not ready yet, waiting 10 seconds..."
      sleep 10
    done

    if [ "$SERVICE_READY" = false ]; then
        echo "$(date): Service failed to become ready after 5 minutes"
        echo "$(date): Container logs:"
        docker logs llm-service
        log_error "LLM service failed to become ready"
    fi

    log_success "LLM service is ready and responding to health checks"

    # Log final status
    echo "$(date): Final container status:"
    docker ps || log_error "Failed to get final container status"
    docker stats --no-stream llm-service || echo "$(date): Warning: Could not get container stats"

    # Setup log rotation for container logs
    echo "$(date): Setting up log rotation..."
    if cat > /etc/logrotate.d/docker-llm << EOF
/var/lib/docker/containers/*/llm-service*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
    then
        log_success "Log rotation configured"
    else
        echo "$(date): Warning: Failed to setup log rotation"
    fi

    echo "$(date): LLM service initialization completed successfully!"
    log_success "All initialization tasks completed"
  EOS

  network_interface {
    network = "default"
    access_config {}
  }

  tags = ["llm"]
}

resource "google_compute_firewall" "llm_firewall" {
  name    = "llm-firewall-rule"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }

  source_ranges = ["0.0.0.0/0"] # WARNING: This allows all IPs. For production, restrict this to specific IPs.
  target_tags   = ["llm"]
}
