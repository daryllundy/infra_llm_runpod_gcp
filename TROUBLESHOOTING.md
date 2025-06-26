# Troubleshooting Guide - Infrastructure LLM Project

This guide helps you diagnose and resolve common issues when deploying the LLM infrastructure on GCP.

## 🚨 Common Issues

### 1. Terraform Deployment Issues

#### Issue: `terraform apply` fails with authentication error
**Symptoms:**
```
Error: google: could not find default credentials
```

**Solution:**
```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

#### Issue: Quota exceeded for GPU instances
**Symptoms:**
```
Error: Quota 'NVIDIA_A100_GPUS' exceeded
```

**Solution:**
1. Check your GPU quota: `gcloud compute project-info describe --project=YOUR_PROJECT`
2. Request quota increase in GCP Console → IAM & Admin → Quotas
3. Consider using a different region or GPU type

#### Issue: Terraform state lock
**Symptoms:**
```
Error: Error locking state: Error acquiring the state lock
```

**Solution:**
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

### 2. VM Startup Issues

#### Issue: VM fails to start LLM service
**Symptoms:**
- VM is running but service not accessible on port 8000
- Health checks fail

**Diagnosis:**
```bash
# SSH into the VM
gcloud compute ssh llm-a100-vllm --zone=us-central1-a

# Check startup logs
sudo tail -f /var/log/llm-startup.log

# Check container status
sudo docker ps -a
sudo docker logs llm-service
```

**Common Causes & Solutions:**

1. **Docker installation failed:**
   ```bash
   # Check if Docker is installed
   docker --version

   # If not, manually install
   sudo apt update
   sudo apt install docker.io -y
   ```

2. **GPU not available:**
   ```bash
   # Check GPU status
   nvidia-smi

   # If command not found, install drivers
   sudo apt install nvidia-driver-470 -y
   sudo reboot
   ```

3. **Container failed to start:**
   ```bash
   # Check container logs
   sudo docker logs llm-service

   # Common issues:
   # - Out of memory: Reduce memory limit in terraform/main.tf
   # - Model not found: Check MODEL_ID variable
   # - Permission issues: Check user/group settings
   ```

### 3. Network Connectivity Issues

#### Issue: Cannot connect to LLM service
**Symptoms:**
- `curl` commands timeout
- Smoke test fails with connection error

**Diagnosis:**
```bash
# Check if VM is running
gcloud compute instances list

# Check firewall rules
gcloud compute firewall-rules list --filter="name:llm-firewall-rule"

# Test from VM itself
gcloud compute ssh llm-a100-vllm --zone=us-central1-a
curl http://localhost:8000/health
```

**Solutions:**

1. **Firewall not configured:**
   ```bash
   # Check if firewall rule exists
   gcloud compute firewall-rules describe llm-firewall-rule

   # If missing, apply Terraform again
   terraform apply
   ```

2. **Wrong external IP:**
   ```bash
   # Get correct external IP
   terraform output endpoint
   # or
   gcloud compute instances describe llm-a100-vllm --zone=us-central1-a --format="get(networkInterfaces[0].accessConfigs[0].natIP)"
   ```

### 4. Authentication Issues

#### Issue: API calls return 401 Unauthorized
**Symptoms:**
```bash
curl http://VM_IP:8000/v1/chat/completions
# Returns: {"detail":"Unauthorized"}
```

**Solution:**
```bash
# Include API key in request
curl -H "Authorization: Bearer your-secret-api-key" http://VM_IP:8000/v1/chat/completions

# Check what API key is configured
gcloud compute ssh llm-a100-vllm --zone=us-central1-a
sudo docker inspect llm-service | grep API_KEY
```

### 5. Performance Issues

#### Issue: Slow response times or timeouts
**Symptoms:**
- Requests take >30 seconds
- Intermittent timeouts

**Diagnosis:**
```bash
# Check container resources
gcloud compute ssh llm-a100-vllm --zone=us-central1-a
sudo docker stats llm-service

# Check GPU utilization
nvidia-smi

# Check system resources
htop
df -h
```

**Solutions:**

1. **Insufficient memory:**
   - Increase memory limit in terraform/main.tf
   - Use smaller model or quantized version

2. **GPU memory issues:**
   ```bash
   # Check GPU memory usage
   nvidia-smi

   # If GPU memory full, restart container
   sudo docker restart llm-service
   ```

## 🔧 Debugging Commands

### Essential Commands for Troubleshooting

```bash
# Get VM status
gcloud compute instances list --filter="name:llm-a100-vllm"

# SSH into VM
gcloud compute ssh llm-a100-vllm --zone=us-central1-a

# Check startup logs
sudo tail -f /var/log/llm-startup.log

# Check container status
sudo docker ps -a
sudo docker logs llm-service --tail 50

# Check system resources
sudo docker stats llm-service
nvidia-smi
free -h
df -h

# Test service locally
curl -H "Authorization: Bearer your-secret-api-key" http://localhost:8000/health

# Check firewall
gcloud compute firewall-rules list --filter="name:llm-firewall-rule"

# Get external IP
terraform output endpoint
```

### Log Locations

- **Startup logs:** `/var/log/llm-startup.log`
- **Container logs:** `sudo docker logs llm-service`
- **System logs:** `/var/log/syslog`
- **Docker daemon logs:** `sudo journalctl -u docker`

## 🔄 Recovery Procedures

### Complete Service Restart

```bash
# SSH into VM
gcloud compute ssh llm-a100-vllm --zone=us-central1-a

# Stop and remove container
sudo docker stop llm-service
sudo docker rm llm-service

# Clean up resources
sudo docker container prune -f
sudo docker image prune -f

# Restart container (get command from startup script)
sudo docker run -d \
  --gpus all \
  -p 8000:8000 \
  -e MODEL_ID=meta-llama/Llama-3-8B-Instruct.Q4_K_M.gguf \
  -e API_KEY=your-secret-api-key \
  --restart unless-stopped \
  --name llm-service \
  --user 1000:1000 \
  --security-opt=no-new-privileges \
  --memory="16g" \
  --memory-swap="16g" \
  vllm/vllm-openai:latest \
  --api-key your-secret-api-key
```

### VM Recreation

```bash
# Destroy and recreate VM
terraform destroy -target=google_compute_instance.llm
terraform apply -target=google_compute_instance.llm
```

### Complete Infrastructure Reset

```bash
# Destroy everything
terraform destroy

# Recreate from scratch
terraform apply
```

## 📞 Getting Help

### Before Asking for Help

1. Check this troubleshooting guide
2. Review the startup logs: `/var/log/llm-startup.log`
3. Check container logs: `sudo docker logs llm-service`
4. Verify your configuration matches the README

### Information to Include

When reporting issues, include:

1. **Error messages** (exact text)
2. **Steps to reproduce** the issue
3. **Environment details:**
   ```bash
   # GCP project and region
   gcloud config get-value project
   gcloud config get-value compute/region

   # Terraform version
   terraform version

   # VM status
   gcloud compute instances describe llm-a100-vllm --zone=us-central1-a
   ```
4. **Relevant logs** (startup logs, container logs)
5. **What you've already tried**

### Useful Resources

- [GCP Compute Engine Documentation](https://cloud.google.com/compute/docs)
- [Docker Troubleshooting](https://docs.docker.com/config/daemon/troubleshoot/)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## 🎯 Prevention Tips

1. **Always test in a development environment first**
2. **Monitor costs** - A100 instances are expensive
3. **Set up billing alerts** in GCP Console
4. **Regularly update base images** for security
5. **Keep backups** of working configurations
6. **Use version control** for all infrastructure code
7. **Document any custom changes** you make

---

*Last updated: December 2024*
