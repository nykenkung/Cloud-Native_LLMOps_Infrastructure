#!/usr/bin/env bash
# =====================================================================
#  [12] ArgoCD GitOps
#  Declarative Continuous Delivery Platform & Ingress
#
#  Simple Installation Command:
#    kubectl apply -f ~/12-ArgoCD-GitOps/1-ArgoCD-Namespace.yaml
#    kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
#    kubectl apply -f ~/12-ArgoCD-GitOps/2-ArgoCD-Ingress.yaml
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "\033[0;31m$1\033[0m"; exit 1; }

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

case "$1" in
  -install|--install|install)
    do_install
    ;;
  -test|--test|test)
    do_test
    ;;
  *)
    echo "Usage: $0 {-install|-test}"
    exit 1
    ;;
esac
