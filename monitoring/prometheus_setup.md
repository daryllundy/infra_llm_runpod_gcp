# Monitoring Setup

To collect metrics from your LLM VM:

1. SSH into the instance.
2. Install Node Exporter:
   ```bash
   sudo apt update
   sudo apt install prometheus-node-exporter -y
   ```
3. Configure Prometheus to scrape `http://<VM_IP>:9100/metrics`.
4. In Grafana, add a dashboard for GPU utilization and latency.
