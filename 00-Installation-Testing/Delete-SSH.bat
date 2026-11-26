set TARGET=WSL_SSH

ssh %TARGET% "rm -rf ~/00-Installation-Testing ~/01-Hardware-OS-Configuration ~/02-AMD-ROCm-DXG ~/03-Kubernetes ~/04-Helm ~/05-External-Secrets-Operator ~/06-Tailscale-Operator ~/07-Cloudflare-Tunnel ~/08-Ingress-Nginx ~/09-JuiceFS-CSI-Driver ~/10-CloudNativePG-DB ~/11-Qdrant-Vector-DB ~/12-ArgoCD-GitOps ~/13-Falco-Security ~/14-Grafana-Prometheus-Stack ~/15-KEDA-Autoscaler ~/16-LLaMAcpp-ROCm ~/17-LiteLLM-Gateway ~/18-Open-WebUI ~/K8s-OIDC-Provider"
pause