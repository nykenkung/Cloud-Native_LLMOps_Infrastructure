set TARGET=WSL_SSH

pushd "%~dp0.."

ssh %TARGET% "mkdir -p ~/00-Installation-Testing ~/01-Hardware-OS-Configuration ~/02-AMD-ROCm-DXG ~/03-Kubernetes ~/04-Helm ~/05-External-Secrets-Operator ~/06-Tailscale-Operator ~/07-Cloudflare-Tunnel ~/08-Ingress-Nginx ~/09-JuiceFS-CSI-Driver ~/10-CloudNativePG-DB ~/11-Qdrant-Vector-DB ~/12-ArgoCD-GitOps ~/13-Falco-Security ~/14-Grafana-Prometheus-Stack ~/15-KEDA-Autoscaler ~/16-LLaMAcpp-ROCm ~/17-LiteLLM-Gateway ~/18-Open-WebUI ~/K8s-OIDC-Provider/.well-known"

scp ^
 "00-Installation-Testing\Menu.sh" ^
 "00-Installation-Testing\01-Hardware-OS-Configuration.sh" ^
 "00-Installation-Testing\02-AMD-ROCm-DXG.sh" ^
 "00-Installation-Testing\03-Kubernetes.sh" ^
 "00-Installation-Testing\04-Helm.sh" ^
 "00-Installation-Testing\05-External-Secrets-Operator.sh" ^
 "00-Installation-Testing\06-Tailscale-Operator.sh" ^
 "00-Installation-Testing\07-Cloudflare-Tunnel.sh" ^
 "00-Installation-Testing\08-Ingress-Nginx.sh" ^
 "00-Installation-Testing\09-JuiceFS-CSI-Driver.sh" ^
 "00-Installation-Testing\10-CloudNativePG-DB.sh" ^
 "00-Installation-Testing\11-Qdrant-Vector-DB.sh" ^
 "00-Installation-Testing\12-ArgoCD-GitOps.sh" ^
 "00-Installation-Testing\13-Falco-Security.sh" ^
 "00-Installation-Testing\14-Grafana-Prometheus-Stack.sh" ^
 "00-Installation-Testing\15-KEDA-Autoscaler.sh" ^
 "00-Installation-Testing\16-LLaMAcpp-ROCm.sh" ^
 "00-Installation-Testing\17-LiteLLM-Gateway.sh" ^
 "00-Installation-Testing\18-Open-WebUI.sh" ^
 "00-Installation-Testing\91-Check-Pod-Status.sh" ^
 "00-Installation-Testing\92-Reveal-ESO-Secrets.sh" ^
 "00-Installation-Testing\100-Download-LLM.sh" ^
 "00-Installation-Testing\101-Test-AI-Stack-E2E.sh" ^
 "00-Installation-Testing\102-Test-Security-Penetration.sh" ^
 "00-Installation-Testing\103-Test-RAG-Benchmark.sh" ^
 "00-Installation-Testing\104-Test-Concurrency-Throughput.sh" ^
 "00-Installation-Testing\105-Test-Context-Stress.sh" ^
 "00-Installation-Testing\106-Test-Needle-In-Haystack.sh" ^
 "00-Installation-Testing\107-Test-LLM-Guardrails-OWASP.sh" ^
 "00-Installation-Testing\108-Test-Cluster-Security-Audit.sh" ^
 "00-Installation-Testing\109-Test-Storage-Persistence-Failover.sh" ^
 "00-Installation-Testing\110-Test-LLM-CLI.sh" ^
 %TARGET%:~/00-Installation-Testing/

scp ^
 "01-Hardware-OS-Configuration\.bashrc" ^
 "01-Hardware-OS-Configuration\wsl.conf" ^
 %TARGET%:~/01-Hardware-OS-Configuration/

scp ^
 "02-AMD-ROCm-DXG\1-AMD-ROCDXG-Namespace.yaml" ^
 "02-AMD-ROCm-DXG\2-AMD-ROCDXG-Deployment.yaml" ^
 %TARGET%:~/02-AMD-ROCm-DXG/

scp "03-Kubernetes\config.yaml" %TARGET%:~/03-Kubernetes/

scp "04-Helm\init-helm-repos.sh" %TARGET%:~/04-Helm/

scp ^
 "05-External-Secrets-Operator\1-External-Secrets-Namespace.yaml" ^
 "05-External-Secrets-Operator\Google-Cloud-Platform-CSS.yaml" ^
 "05-External-Secrets-Operator\wif-credentials.json" ^
 %TARGET%:~/05-External-Secrets-Operator/

scp ^
 "06-Tailscale-Operator\1-Tailscale-Namespace.yaml" ^
 "06-Tailscale-Operator\2-Tailscale-ProxyGroup.yaml" ^
 "06-Tailscale-Operator\My-Tailscale-ExternalSecret.yaml" ^
 %TARGET%:~/06-Tailscale-Operator/

scp ^
 "07-Cloudflare-Tunnel\1-Cloudflare-KV-Namespace.yaml" ^
 "07-Cloudflare-Tunnel\2-Cloudflare-KV-ServiceAccount.yaml" ^
 "07-Cloudflare-Tunnel\3-Cloudflare-KV-RBAC.yaml" ^
 "07-Cloudflare-Tunnel\4-Cloudflare-KV-RoleBinding.yaml" ^
 "07-Cloudflare-Tunnel\5-Cloudflare-ES-RBAC.yaml" ^
 "07-Cloudflare-Tunnel\6-Cloudflare-ES-RoleBinding.yaml" ^
 "07-Cloudflare-Tunnel\7-Cloudflare-KV-CronJob.yaml" ^
 "07-Cloudflare-Tunnel\8-Cloudflared-Tunnel-Deployment.yaml" ^
 "07-Cloudflare-Tunnel\My-Cloudflare-KV-ExternalSecret.yaml" ^
 "07-Cloudflare-Tunnel\My-Cloudflare-Tunnel-ExternalSecret.yaml" ^
 %TARGET%:~/07-Cloudflare-Tunnel/

scp "08-Ingress-Nginx\1-Ingress-Nginx-Namespace.yaml" %TARGET%:~/08-Ingress-Nginx/

scp ^
 "09-JuiceFS-CSI-Driver\1-Cloudflare-JuiceFS-StorageClass.yaml" ^
 "09-JuiceFS-CSI-Driver\2-Cloudflare-JuiceFS-Postgres.yaml" ^
 "09-JuiceFS-CSI-Driver\My-Cloudflare-JuiceFS-ExternalSecret.yaml" ^
 %TARGET%:~/09-JuiceFS-CSI-Driver/

scp ^
 "10-CloudNativePG-DB\1-CloudNativePG-Namespace.yaml" ^
 "10-CloudNativePG-DB\2-CloudNativePG-Operator.yaml" ^
 %TARGET%:~/10-CloudNativePG-DB/

scp ^
 "11-Qdrant-Vector-DB\1-Qdrant-Namespace.yaml" ^
 "11-Qdrant-Vector-DB\2-Qdrant-Ingress.yaml" ^
 "11-Qdrant-Vector-DB\My-Qdrant-ExternalSecret.yaml" ^
 %TARGET%:~/11-Qdrant-Vector-DB/

scp ^
 "12-ArgoCD-GitOps\1-ArgoCD-Namespace.yaml" ^
 "12-ArgoCD-GitOps\2-ArgoCD-Ingress.yaml" ^
 "12-ArgoCD-GitOps\3-ArgoCD-Install.yaml" ^
 "12-ArgoCD-GitOps\ArgoCD-App-External-Secrets.yaml" ^
 "12-ArgoCD-GitOps\My-ArgoCD-ExternalSecret.yaml" ^
 %TARGET%:~/12-ArgoCD-GitOps/

scp ^
 "13-Falco-Security\1-Falco-Namespace.yaml" ^
 "13-Falco-Security\2-Falco-Ingress.yaml" ^
 "13-Falco-Security\My-Falco-Config.yaml" ^
 "13-Falco-Security\My-Falco-ExternalSecret.yaml" ^
 %TARGET%:~/13-Falco-Security/

scp ^
 "14-Grafana-Prometheus-Stack\1-Grafana-Namespace.yaml" ^
 "14-Grafana-Prometheus-Stack\2-Grafana-Ingress.yaml" ^
 "14-Grafana-Prometheus-Stack\3-Grafana-LLaMAcpp-ROCm.yaml" ^
 "14-Grafana-Prometheus-Stack\My-Grafana-Config.yaml" ^
 "14-Grafana-Prometheus-Stack\My-Grafana-ExternalSecret.yaml" ^
 %TARGET%:~/14-Grafana-Prometheus-Stack/

scp "15-KEDA-Autoscaler\1-LLaMAcpp-KEDA-ScaledObject.yaml" %TARGET%:~/15-KEDA-Autoscaler/

scp ^
 "16-LLaMAcpp-ROCm\1-LLaMAcpp-Namespace.yaml" ^
 "16-LLaMAcpp-ROCm\2-LLaMAcpp-PersistentVolumeClaim.yaml" ^
 "16-LLaMAcpp-ROCm\3-LLaMAcpp-Deployment.yaml" ^
 "16-LLaMAcpp-ROCm\4-LLaMAcpp-Service.yaml" ^
 "16-LLaMAcpp-ROCm\5-LLaMAcpp-ServiceMonitor.yaml" ^
 "16-LLaMAcpp-ROCm\6-LLaMAcpp-NetworkPolicy.yaml" ^
 "16-LLaMAcpp-ROCm\My-LLaMAcpp-ExternalSecret.yaml" ^
 %TARGET%:~/16-LLaMAcpp-ROCm/

scp ^
 "17-LiteLLM-Gateway\1-LiteLLM-Namespace.yaml" ^
 "17-LiteLLM-Gateway\2-LiteLLM-Postgres-Cluster.yaml" ^
 "17-LiteLLM-Gateway\3-LiteLLM-Deployment.yaml" ^
 "17-LiteLLM-Gateway\4-LiteLLM-Service.yaml" ^
 "17-LiteLLM-Gateway\5-LiteLLM-ServiceMonitor.yaml" ^
 "17-LiteLLM-Gateway\6-LiteLLM-NetworkPolicy.yaml" ^
 "17-LiteLLM-Gateway\7-LiteLLM-Ingress.yaml" ^
 "17-LiteLLM-Gateway\My-LiteLLM-Config.yaml" ^
 "17-LiteLLM-Gateway\My-LiteLLM-ExternalSecret.yaml" ^
 %TARGET%:~/17-LiteLLM-Gateway/

scp ^
 "18-Open-WebUI\1-OpenWebUI-Namespace.yaml" ^
 "18-Open-WebUI\2-OpenWebUI-Postgres-Cluster.yaml" ^
 "18-Open-WebUI\3-OpenWebUI-Deployment.yaml" ^
 "18-Open-WebUI\4-OpenWebUI-Service.yaml" ^
 "18-Open-WebUI\5-OpenWebUI-NetworkPolicy.yaml" ^
 "18-Open-WebUI\6-OpenWebUI-Ingress.yaml" ^
 "18-Open-WebUI\My-OpenWebUI-Config.yaml" ^
 "18-Open-WebUI\My-OpenWebUI-ExternalSecret.yaml" ^
 %TARGET%:~/18-Open-WebUI/

scp "K8s-OIDC-Provider\jwks.json" %TARGET%:~/K8s-OIDC-Provider/
scp "K8s-OIDC-Provider\.well-known\openid-configuration" %TARGET%:~/K8s-OIDC-Provider/.well-known/

ssh %TARGET% "sed -i 's/\r$//' ~/00-Installation-Testing/*.sh ~/04-Helm/*.sh && chmod +x ~/00-Installation-Testing/*.sh ~/04-Helm/*.sh"

popd
pause