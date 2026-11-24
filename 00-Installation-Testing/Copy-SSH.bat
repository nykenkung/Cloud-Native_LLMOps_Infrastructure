@echo off
set ORGIN=E:\CISC4900
set TARGET=WSL_SSH

ssh %TARGET% "mkdir -p ~/.cloudflared ~/00-Installation-Testing ~/01-Hardware-OS-Configuration ~/02-AMD-ROCm-DXG ~/03-Kubernetes ~/04-Helm ~/05-External-Secrets-Operator ~/06-Tailscale-Operator ~/07-Cloudflare-Tunnel ~/08-Ingress-Nginx ~/09-JuiceFS-CSI-Driver ~/10-CloudNativePG-DB ~/11-Qdrant-Vector-DB ~/12-ArgoCD-GitOps ~/13-Falco-Security ~/14-Grafana-Prometheus-Stack ~/15-KEDA-Autoscaler ~/16-LLaMAcpp-ROCm ~/17-LiteLLM-Gateway ~/18-Open-WebUI ~/HuggingFace-Models && sudo mkdir -p /etc/rancher/k3s && sudo chown -R $(id -un):$(id -gn) /etc/rancher/k3s"

scp "%ORGIN%\00-Installation-Testing\00-Menu.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\01-Hardware-OS-Configuration.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\02-AMD-ROCm-DXG.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\03-Kubernetes.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\04-Helm.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\05-External-Secrets-Operator.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\06-Tailscale-Operator.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\07-Cloudflare-Tunnel.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\08-Ingress-Nginx.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\09-JuiceFS-CSI-Driver.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\10-CloudNativePG-DB.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\11-Qdrant-Vector-DB.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\12-ArgoCD-GitOps.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\13-Falco-Security.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\14-Grafana-Prometheus-Stack.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\15-KEDA-Autoscaler.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\16-LLaMAcpp-ROCm.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\17-LiteLLM-Gateway.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\18-Open-WebUI.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\100-Download-LLM.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\101-Test-AI-Stack-E2E.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\102-Test-Security-Penetration.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\103-Test-RAG-Benchmark.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\104-Test-Concurrency-Throughput.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\105-Test-Context-Stress.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\106-Test-Needle-In-Haystack.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\107-Test-LLM-Guardrails-OWASP.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\108-Test-Cluster-Security-Audit.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\109-Test-Storage-Persistence-Failover.sh" %TARGET%:~/00-Installation-Testing/
scp "%ORGIN%\00-Installation-Testing\110-Test-LLM-CLI.sh" %TARGET%:~/00-Installation-Testing/

scp "%ORGIN%\01-Hardware-OS-Configuration\.bashrc" %TARGET%:~/01-Hardware-OS-Configuration/
scp "%ORGIN%\01-Hardware-OS-Configuration\wsl.conf" %TARGET%:~/01-Hardware-OS-Configuration/
scp "%ORGIN%\01-Hardware-OS-Configuration\.cloudflared\b46a5faa-d46c-4544-acae-9154035d9b5e.json" %TARGET%:~/.cloudflared/
scp "%ORGIN%\01-Hardware-OS-Configuration\.cloudflared\config.yaml" %TARGET%:~/.cloudflared/

scp "%ORGIN%\02-AMD-ROCm-DXG\1-AMD-ROCDXG-Namespace.yaml" %TARGET%:~/02-AMD-ROCm-DXG/
scp "%ORGIN%\02-AMD-ROCm-DXG\2-AMD-ROCDXG-Deployment.yaml" %TARGET%:~/02-AMD-ROCm-DXG/

scp "%ORGIN%\03-Kubernetes\config.yaml" %TARGET%:/etc/rancher/k3s/
scp "%ORGIN%\03-Kubernetes\k3s.yaml" %TARGET%:/etc/rancher/k3s/

scp "%ORGIN%\04-Helm\init-helm-repos.sh" %TARGET%:~/04-Helm/

scp "%ORGIN%\05-External-Secrets-Operator\1-External-Secrets-Namespace.yaml" %TARGET%:~/05-External-Secrets-Operator/
scp "%ORGIN%\05-External-Secrets-Operator\Google-Cloud-Platform-CSS.yaml" %TARGET%:~/05-External-Secrets-Operator/
scp "%ORGIN%\05-External-Secrets-Operator\wif-credentials.json" %TARGET%:~/05-External-Secrets-Operator/

scp "%ORGIN%\06-Tailscale-Operator\1-Tailscale-Namespace.yaml" %TARGET%:~/06-Tailscale-Operator/
scp "%ORGIN%\06-Tailscale-Operator\2-Tailscale-ProxyGroup.yaml" %TARGET%:~/06-Tailscale-Operator/
scp "%ORGIN%\06-Tailscale-Operator\My-Tailscale-ExternalSecret.yaml" %TARGET%:~/06-Tailscale-Operator/

scp "%ORGIN%\07-Cloudflare-Tunnel\1-Cloudflare-KV-Namespace.yaml" %TARGET%:~/07-Cloudflare-Tunnel/
scp "%ORGIN%\07-Cloudflare-Tunnel\2-Cloudflare-KV-ServiceAccount.yaml" %TARGET%:~/07-Cloudflare-Tunnel/
scp "%ORGIN%\07-Cloudflare-Tunnel\3-Cloudflare-KV-RBAC.yaml" %TARGET%:~/07-Cloudflare-Tunnel/
scp "%ORGIN%\07-Cloudflare-Tunnel\4-Cloudflare-KV-RoleBinding.yaml" %TARGET%:~/07-Cloudflare-Tunnel/
scp "%ORGIN%\07-Cloudflare-Tunnel\5-Cloudflare-ES-RBAC.yaml" %TARGET%:~/07-Cloudflare-Tunnel/
scp "%ORGIN%\07-Cloudflare-Tunnel\6-Cloudflare-ES-RoleBinding.yaml" %TARGET%:~/07-Cloudflare-Tunnel/
scp "%ORGIN%\07-Cloudflare-Tunnel\7-Cloudflare-KV-CronJob.yaml" %TARGET%:~/07-Cloudflare-Tunnel/
scp "%ORGIN%\07-Cloudflare-Tunnel\8-Cloudflared-Tunnel-Deployment.yaml" %TARGET%:~/07-Cloudflare-Tunnel/
scp "%ORGIN%\07-Cloudflare-Tunnel\My-Cloudflare-ExternalSecret.yaml" %TARGET%:~/07-Cloudflare-Tunnel/

scp "%ORGIN%\08-Ingress-Nginx\1-Ingress-Nginx-Namespace.yaml" %TARGET%:~/08-Ingress-Nginx/

scp "%ORGIN%\09-JuiceFS-CSI-Driver\1-Cloudflare-JuiceFS-StorageClass.yaml" %TARGET%:~/09-JuiceFS-CSI-Driver/
scp "%ORGIN%\09-JuiceFS-CSI-Driver\2-Cloudflare-JuiceFS-Postgres.yaml" %TARGET%:~/09-JuiceFS-CSI-Driver/
scp "%ORGIN%\09-JuiceFS-CSI-Driver\My-Cloudflare-JuiceFS-ExternalSecret.yaml" %TARGET%:~/09-JuiceFS-CSI-Driver/

scp "%ORGIN%\10-CloudNativePG-DB\1-CloudNativePG-Namespace.yaml" %TARGET%:~/10-CloudNativePG-DB/
scp "%ORGIN%\10-CloudNativePG-DB\2-CloudNativePG-Operator.yaml" %TARGET%:~/10-CloudNativePG-DB/

scp "%ORGIN%\11-Qdrant-Vector-DB\1-Qdrant-Namespace.yaml" %TARGET%:~/11-Qdrant-Vector-DB/
scp "%ORGIN%\11-Qdrant-Vector-DB\2-Qdrant-Ingress.yaml" %TARGET%:~/11-Qdrant-Vector-DB/
scp "%ORGIN%\11-Qdrant-Vector-DB\My-Qdrant-ExternalSecret.yaml" %TARGET%:~/11-Qdrant-Vector-DB/

scp "%ORGIN%\12-ArgoCD-GitOps\1-ArgoCD-Namespace.yaml" %TARGET%:~/12-ArgoCD-GitOps/
scp "%ORGIN%\12-ArgoCD-GitOps\2-ArgoCD-Ingress.yaml" %TARGET%:~/12-ArgoCD-GitOps/
scp "%ORGIN%\12-ArgoCD-GitOps\3-ArgoCD-Install.yaml" %TARGET%:~/12-ArgoCD-GitOps/
scp "%ORGIN%\12-ArgoCD-GitOps\My-ArgoCD-ExternalSecret.yaml" %TARGET%:~/12-ArgoCD-GitOps/

scp "%ORGIN%\13-Falco-Security\1-Falco-Namespace.yaml" %TARGET%:~/13-Falco-Security/
scp "%ORGIN%\13-Falco-Security\2-Falco-Ingress.yaml" %TARGET%:~/13-Falco-Security/
scp "%ORGIN%\13-Falco-Security\My-Falco-Config.yaml" %TARGET%:~/13-Falco-Security/
scp "%ORGIN%\13-Falco-Security\My-Falco-ExternalSecret.yaml" %TARGET%:~/13-Falco-Security/

scp "%ORGIN%\14-Grafana-Prometheus-Stack\1-Grafana-Namespace.yaml" %TARGET%:~/14-Grafana-Prometheus-Stack/
scp "%ORGIN%\14-Grafana-Prometheus-Stack\2-Grafana-Ingress.yaml" %TARGET%:~/14-Grafana-Prometheus-Stack/
scp "%ORGIN%\14-Grafana-Prometheus-Stack\3-Grafana-LLaMAcpp-ROCm.yaml" %TARGET%:~/14-Grafana-Prometheus-Stack/
scp "%ORGIN%\14-Grafana-Prometheus-Stack\My-Grafana-Config.yaml" %TARGET%:~/14-Grafana-Prometheus-Stack/
scp "%ORGIN%\14-Grafana-Prometheus-Stack\My-Grafana-ExternalSecret.yaml" %TARGET%:~/14-Grafana-Prometheus-Stack/

scp "%ORGIN%\15-KEDA-Autoscaler\1-LLaMAcpp-KEDA-ScaledObject.yaml" %TARGET%:~/15-KEDA-Autoscaler/

scp "%ORGIN%\16-LLaMAcpp-ROCm\1-LLaMAcpp-Namespace.yaml" %TARGET%:~/16-LLaMAcpp-ROCm/
scp "%ORGIN%\16-LLaMAcpp-ROCm\2-LLaMAcpp-PersistentVolumeClaim.yaml" %TARGET%:~/16-LLaMAcpp-ROCm/
scp "%ORGIN%\16-LLaMAcpp-ROCm\3-LLaMAcpp-Deployment.yaml" %TARGET%:~/16-LLaMAcpp-ROCm/
scp "%ORGIN%\16-LLaMAcpp-ROCm\4-LLaMAcpp-Service.yaml" %TARGET%:~/16-LLaMAcpp-ROCm/
scp "%ORGIN%\16-LLaMAcpp-ROCm\5-LLaMAcpp-ServiceMonitor.yaml" %TARGET%:~/16-LLaMAcpp-ROCm/
scp "%ORGIN%\16-LLaMAcpp-ROCm\6-LLaMAcpp-NetworkPolicy.yaml" %TARGET%:~/16-LLaMAcpp-ROCm/
scp "%ORGIN%\16-LLaMAcpp-ROCm\My-LLaMAcpp-ExternalSecret.yaml" %TARGET%:~/16-LLaMAcpp-ROCm/

scp "%ORGIN%\17-LiteLLM-Gateway\1-LiteLLM-Namespace.yaml" %TARGET%:~/17-LiteLLM-Gateway/
scp "%ORGIN%\17-LiteLLM-Gateway\2-LiteLLM-Postgres-Cluster.yaml" %TARGET%:~/17-LiteLLM-Gateway/
scp "%ORGIN%\17-LiteLLM-Gateway\3-LiteLLM-Deployment.yaml" %TARGET%:~/17-LiteLLM-Gateway/
scp "%ORGIN%\17-LiteLLM-Gateway\4-LiteLLM-Service.yaml" %TARGET%:~/17-LiteLLM-Gateway/
scp "%ORGIN%\17-LiteLLM-Gateway\5-LiteLLM-ServiceMonitor.yaml" %TARGET%:~/17-LiteLLM-Gateway/
scp "%ORGIN%\17-LiteLLM-Gateway\6-LiteLLM-NetworkPolicy.yaml" %TARGET%:~/17-LiteLLM-Gateway/
scp "%ORGIN%\17-LiteLLM-Gateway\7-LiteLLM-Ingress.yaml" %TARGET%:~/17-LiteLLM-Gateway/
scp "%ORGIN%\17-LiteLLM-Gateway\My-LiteLLM-Config.yaml" %TARGET%:~/17-LiteLLM-Gateway/
scp "%ORGIN%\17-LiteLLM-Gateway\My-LiteLLM-ExternalSecret.yaml" %TARGET%:~/17-LiteLLM-Gateway/

scp "%ORGIN%\18-Open-WebUI\1-OpenWebUI-Namespace.yaml" %TARGET%:~/18-Open-WebUI/
scp "%ORGIN%\18-Open-WebUI\2-OpenWebUI-Postgres-Cluster.yaml" %TARGET%:~/18-Open-WebUI/
scp "%ORGIN%\18-Open-WebUI\3-OpenWebUI-Deployment.yaml" %TARGET%:~/18-Open-WebUI/
scp "%ORGIN%\18-Open-WebUI\4-OpenWebUI-Service.yaml" %TARGET%:~/18-Open-WebUI/
scp "%ORGIN%\18-Open-WebUI\5-OpenWebUI-NetworkPolicy.yaml" %TARGET%:~/18-Open-WebUI/
scp "%ORGIN%\18-Open-WebUI\6-Open-WebUI-Ingress.yaml" %TARGET%:~/18-Open-WebUI/
scp "%ORGIN%\18-Open-WebUI\My-OpenWebUI-Config.yaml" %TARGET%:~/18-Open-WebUI/
scp "%ORGIN%\18-Open-WebUI\My-OpenWebUI-ExternalSecret.yaml" %TARGET%:~/18-Open-WebUI/

ssh %TARGET% "chmod +x ~/00-Installation-Testing/*.sh"
pause
