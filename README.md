<h1 align="center">Infra-to-LLM: Effortless LLM Deployment on GCP</h1>

<p align="center">
  <b>Automated, secure, and production-ready infrastructure for deploying LLaMA/Mistral with vLLM on Google Cloud Platform.</b>
  <br>
  <a href="#getting-started"><strong>Get Started »</strong></a>
  <br>
  <br>
  <a href="#features">Features</a>
  ·
  <a href="#contributing">Contributing</a>
  ·
  <a href="#for-hiring-managers--recruiters">For Hiring Managers</a>
  ·
  <a href="#security">Security</a>
</p>

<p align="center">
  <img alt="GitHub stars" src="https://img.shields.io/github/stars/daryllundy/infra_llm_runpod_gcp?style=social">
  <img alt="GitHub forks" src="https://img.shields.io/github/forks/daryllundy/infra_llm_runpod_gcp?style=social">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue.svg">
  <img alt="PRs Welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg">
</p>

---

## 🚀 Project Overview

**Infra-to-LLM** is an open-source, production-grade template for deploying state-of-the-art LLMs (LLaMA, Mistral) on GCP using Terraform and vLLM. Designed for speed, security, and scalability, it empowers ML engineers, researchers, and startups to launch powerful inference endpoints in minutes—not days.

- **Why?** Most LLM infra guides are incomplete, insecure, or hard to reproduce. This repo is different: it's auditable, modular, and ready for real-world use.

---

## ✨ Features

- **One-Click GCP Deployment:** Automated with Terraform
- **RunPod Spec Reference:** Seamless migration from RunPod to GCP
- **Security First:** API key auth, firewall rules, non-root containers, and more
- **Monitoring Ready:** Prometheus/Grafana integration
- **Cost Awareness:** Warnings and tips to avoid surprise bills
- **Easy Customization:** Modular structure for your own models or infra tweaks

---

## 🏁 Getting Started

### 1. Validate on RunPod

```bash
# Install runpodctl CLI
# Create A40 pod with vLLM image
runpodctl get pod llm-a40-vllm -o yaml > runpod-spec.yaml
bash scripts/smoke_test.sh
```

### 2. Deploy on GCP

```bash
cd terraform/
# Edit variables.tf with your GCP project and a secure API key
terraform init
terraform apply -auto-approve
terraform output endpoint
```

---

## 🔒 Security

- **API Key Auth:** Change the default API key in `terraform/variables.tf`:
  ```hcl
  variable "API_KEY" {
    description = "API key for vLLM service"
    default     = "your-secure-api-key-here"  # Replace with a strong, unique key
  }
  ```
- **Usage Example:**
  ```bash
  curl -H "Authorization: Bearer your-secure-api-key-here" http://VM_IP:8000/v1/chat/completions
  ```
- **Firewall:** Restrict access in `terraform/main.tf`:
  ```hcl
  source_ranges = ["YOUR_OFFICE_IP/32", "YOUR_VPN_RANGE/24"]
  ```
- **Container Security:** Non-root user, memory limits, no-new-privileges, log rotation

**Security Checklist:**
- [ ] Change default API key
- [ ] Restrict firewall to trusted IPs
- [ ] Monitor logs
- [ ] Keep images updated
- [ ] Rotate API keys
- [ ] Consider GCP IAM

---

## 📊 Monitoring

- See [monitoring/prometheus_setup.md](monitoring/prometheus_setup.md) for Prometheus/Grafana setup.
- Check `/var/log/llm-startup.log` on the VM for deployment logs.

---

## 🤝 Contributing

We welcome issues, feature requests, and PRs!
Whether you're a cloud engineer, ML enthusiast, or just curious, your input makes this project better.

- See [tasks.md](tasks.md) for open issues and roadmap.
- Please follow our [contribution guidelines](CONTRIBUTING.md) (coming soon).

---

## 💼 For Hiring Managers & Recruiters

This project demonstrates:
- **Cloud Infrastructure Mastery:** Secure, automated, and scalable GCP deployments
- **DevOps Best Practices:** IaC, modular code, CI/CD readiness
- **Security Focus:** Principle of least privilege, auditable configs
- **Open Source Leadership:** Clear docs, community focus, and maintainability

If you're looking for someone who can build robust ML infra, drive open source, and communicate clearly, let's connect!

---

## 📝 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 📬 Contact

Created and maintained by [Daryl](https://github.com/daryllundy).
Questions, feedback, or want to collaborate? Open an issue or reach out on GitHub!
