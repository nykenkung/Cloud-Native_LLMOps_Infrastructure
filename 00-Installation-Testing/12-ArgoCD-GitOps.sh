#!/usr/bin/env bash
# =====================================================================
#  [12] ArgoCD GitOps
#  Declarative Continuous Delivery Platform & Ingress
#
#  Usage: ./12-ArgoCD-GitOps.sh {-install|-test|-restart|-uninstall}
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "$1"; exit 1; }

do_install() {
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$HOME/12-ArgoCD-GitOps/1-ArgoCD-Namespace.yaml" || true
  if [ -f "$HOME/12-ArgoCD-GitOps/3-ArgoCD-Install.yaml" ]; then
    kubectl apply --server-side --force-conflicts -n argocd -f "$HOME/12-ArgoCD-GitOps/3-ArgoCD-Install.yaml" || true
  else
    kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true
  fi
  kubectl apply -f "$HOME/12-ArgoCD-GitOps/My-ArgoCD-ExternalSecret.yaml" || true
  kubectl -n argocd patch secret argocd-secret -p '{"stringData": {"admin.password": "$2b$12$d3gihZUIn8lMCGsq1d5pA.PkTKxpm0b4qLOCnHv7j5PrEN/ZQeweG", "admin.passwordMtime": "'$(date +%FT%T%Z)'"}}' || true
  kubectl apply -f "$HOME/12-ArgoCD-GitOps/2-ArgoCD-Ingress.yaml" || true
  echo "=== [12 Installation Finished Successfully] ==="
}

do_test() {
  ARGOCD_READY=$(kubectl get pods -n argocd --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$ARGOCD_READY" -gt 0 ]; then
    echo "[OK] ArgoCD is Running ($ARGOCD_READY pods)"
  else
    fail_exit "[FAIL] ArgoCD pods are not Running"
  fi
  echo "=== [12 Verification Completed Successfully] ==="
}

do_restart() {
  do_install
  kubectl get externalsecret -n argocd --no-headers 2>/dev/null | awk '{print $1}' | while read -r name; do
    [ -n "$name" ] && kubectl annotate externalsecret "$name" -n argocd force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  kubectl rollout restart deploy -n argocd 2>/dev/null || true
  kubectl rollout restart sts -n argocd 2>/dev/null || true
  echo "=== [12 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  [ -f "$HOME/12-ArgoCD-GitOps/2-ArgoCD-Ingress.yaml" ] && kubectl delete -f "$HOME/12-ArgoCD-GitOps/2-ArgoCD-Ingress.yaml" --ignore-not-found 2>/dev/null || true
  [ -f "$HOME/12-ArgoCD-GitOps/My-ArgoCD-ExternalSecret.yaml" ] && kubectl delete -f "$HOME/12-ArgoCD-GitOps/My-ArgoCD-ExternalSecret.yaml" --ignore-not-found 2>/dev/null || true
  [ -f "$HOME/12-ArgoCD-GitOps/3-ArgoCD-Install.yaml" ] && kubectl delete -n argocd -f "$HOME/12-ArgoCD-GitOps/3-ArgoCD-Install.yaml" --ignore-not-found 2>/dev/null || true
  kubectl delete ns argocd --ignore-not-found 2>/dev/null || true
  echo "=== [12 Uninstallation Completed Successfully] ==="
}

case "$1" in
  -install)   do_install ;;
  -test)      do_test ;;
  -restart)   do_restart ;;
  -uninstall) do_uninstall ;;
  *)
    echo "Usage: $0 {-install|-test|-restart|-uninstall}"
    exit 1
    ;;
esac
